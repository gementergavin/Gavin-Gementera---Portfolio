<#
    AdminTools - help desk and sysadmin functions for the Pacific Crest Unified
    School District (fictional) Active Directory lab.

    Works in Windows PowerShell 5.1 (built into Windows Server) and PowerShell 7.

    Functions that change Active Directory support -WhatIf and -Confirm.
    The small "pure" helpers (usernames, passwords, validation, date and disk
    math) don't touch AD, so the Pester tests can check them on any PC.
#>

Set-StrictMode -Version Latest

$script:ValidRoles = @('Teacher', 'Office', 'IT', 'Student')
$script:AmbiguousChars = '0O1lI'

# ===========================================================================
# Pure helpers (no Active Directory needed)
# ===========================================================================

function ConvertTo-PcusdUsername {
    <#
    .SYNOPSIS
        Builds a first.last username: lowercase, letters only, at most 20
        characters (the sAMAccountName limit), unique among ExistingNames.
    .EXAMPLE
        ConvertTo-PcusdUsername -FirstName 'José' -LastName "O'Brien"    # jose.obrien
    .EXAMPLE
        ConvertTo-PcusdUsername Maria Lopez -ExistingNames 'maria.lopez' # maria.lopez2
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)] [string] $FirstName,
        [Parameter(Mandatory, Position = 1)] [string] $LastName,
        [string[]] $ExistingNames = @()
    )

    $first = ConvertTo-PlainLetters -Text $FirstName
    $last  = ConvertTo-PlainLetters -Text $LastName
    if (-not $first -or -not $last) {
        throw "Can't build a username from '$FirstName $LastName'."
    }

    $taken = @()
    if ($ExistingNames) { $taken = @($ExistingNames | ForEach-Object { $_.ToLowerInvariant() }) }

    $base      = "$first.$last"
    $candidate = (Get-Truncated -Text $base -MaxLength 20)
    $number    = 2
    while ($taken -contains $candidate) {
        $suffix    = [string]$number
        $candidate = (Get-Truncated -Text $base -MaxLength (20 - $suffix.Length)) + $suffix
        $number++
    }
    return $candidate
}

function ConvertTo-PlainLetters {
    # "José" -> "jose", "O'Brien" -> "obrien", "Smith-Jones" -> "smithjones"
    param([string] $Text)
    $decomposed = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $decomposed.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    return ($builder.ToString().ToLowerInvariant() -replace '[^a-z]', '')
}

function Get-Truncated {
    # Cut to MaxLength and never end on the dot between first and last name
    param([string] $Text, [int] $MaxLength)
    if ($Text.Length -gt $MaxLength) { $Text = $Text.Substring(0, $MaxLength) }
    return $Text.TrimEnd('.')
}

function Get-RowValue {
    # Value of a CSV column, or '' if the column doesn't exist (safe under StrictMode)
    param([psobject] $Row, [string] $Name)
    if ($Row.PSObject.Properties.Name -contains $Name -and $null -ne $Row.$Name) { return ([string]$Row.$Name).Trim() }
    return ''
}

function Get-SecureRandomIndex {
    # Random integer from 0 to Max-1 using the OS's cryptographic random generator
    param([Parameter(Mandatory)] [int] $Max)
    $bytes = New-Object byte[] 4
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [int]([BitConverter]::ToUInt32($bytes, 0) % [uint32]$Max)
}

function New-PcusdTempPassword {
    <#
    .SYNOPSIS
        Random temporary password with at least one uppercase letter,
        lowercase letter, digit and symbol. Leaves out characters that are
        easy to misread over the phone (0 O 1 l I).
    .EXAMPLE
        New-PcusdTempPassword -Length 16
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateRange(12, 64)] [int] $Length = 14
    )

    $sets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ',
        'abcdefghijkmnopqrstuvwxyz',
        '23456789',
        '!@#$%*?-+='
    )
    $all = -join $sets

    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($set in $sets) { $chars.Add($set[(Get-SecureRandomIndex -Max $set.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[(Get-SecureRandomIndex -Max $all.Length)]) }

    # Fisher-Yates shuffle so the guaranteed characters aren't always first
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = Get-SecureRandomIndex -Max ($i + 1)
        $swap = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $swap
    }
    return -join $chars
}

function Test-PcusdUserRow {
    <#
    .SYNOPSIS
        Checks one CSV row before an account is created. Returns a list of
        problems; no output means the row is good. Call it as
        @(Test-PcusdUserRow -Row $row) to always get an array.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [psobject] $Row)

    $problems = @()
    $names = $Row.PSObject.Properties.Name

    foreach ($column in 'FirstName', 'LastName', 'Role') {
        if ($names -notcontains $column -or [string]::IsNullOrWhiteSpace($Row.$column)) {
            $problems += "$column is missing"
        }
    }
    foreach ($column in 'FirstName', 'LastName') {
        if ($names -contains $column -and -not [string]::IsNullOrWhiteSpace($Row.$column) -and
            -not (ConvertTo-PlainLetters -Text $Row.$column)) {
            $problems += "$column has no letters"
        }
    }
    if ($names -contains 'Role' -and -not [string]::IsNullOrWhiteSpace($Row.Role) -and
        $script:ValidRoles -notcontains $Row.Role.Trim()) {
        $problems += "Role '$($Row.Role)' must be one of: $($script:ValidRoles -join ', ')"
    }
    if ($names -contains 'IdNumber' -and -not [string]::IsNullOrWhiteSpace($Row.IdNumber) -and
        $Row.IdNumber.Trim() -notmatch '^\d{4,10}$') {
        $problems += "IdNumber '$($Row.IdNumber)' must be 4-10 digits"
    }
    return $problems
}

function Get-PcusdRoleSettings {
    <#
    .SYNOPSIS
        Where a role's accounts live and which role group they join.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Role)

    switch ($Role.Trim()) {
        'Teacher' { return @{ OU = 'OU=Teachers,OU=Staff,OU=PCUSD'; Group = 'GG-Teachers' } }
        'Office'  { return @{ OU = 'OU=Office,OU=Staff,OU=PCUSD';   Group = 'GG-Office' } }
        'IT'      { return @{ OU = 'OU=IT,OU=Staff,OU=PCUSD';       Group = 'GG-IT' } }
        'Student' { return @{ OU = 'OU=Students,OU=PCUSD';          Group = 'GG-Students' } }
        default   { throw "Unknown role '$Role'. Use one of: $($script:ValidRoles -join ', ')" }
    }
}

function Get-PasswordExpiryStatus {
    <#
    .SYNOPSIS
        Turns AD's msDS-UserPasswordExpiryTimeComputed value into a date,
        days left and a status. Returns nothing for passwords that never expire.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [Int64] $ExpiryFileTime,
        [datetime] $Now = (Get-Date)
    )

    if ($ExpiryFileTime -eq [Int64]::MaxValue) { return }     # never expires
    if ($ExpiryFileTime -eq 0) {                              # "must change at next logon"
        return [pscustomobject]@{ Expires = $null; DaysLeft = 0; Status = 'Must change at sign-in' }
    }

    $expires  = [DateTime]::FromFileTime($ExpiryFileTime)
    $daysLeft = [int][Math]::Floor(($expires - $Now).TotalDays)
    $status   = if ($expires -le $Now) { 'Expired' } else { 'Expiring' }
    return [pscustomobject]@{ Expires = $expires; DaysLeft = $daysLeft; Status = $status }
}

function Get-DiskStatus {
    <#
    .SYNOPSIS
        Percent free and an OK/Low/Critical status for one disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [double] $SizeBytes,
        [Parameter(Mandatory)] [double] $FreeBytes,
        [ValidateRange(1, 99)] [int] $WarnPercent = 15,
        [ValidateRange(1, 99)] [int] $CriticalPercent = 5
    )

    if ($SizeBytes -le 0) { throw 'SizeBytes must be greater than zero.' }
    $percentFree = [Math]::Round(($FreeBytes / $SizeBytes) * 100, 1)
    $status = 'OK'
    if ($percentFree -lt $WarnPercent)     { $status = 'Low' }
    if ($percentFree -lt $CriticalPercent) { $status = 'Critical' }

    return [pscustomobject]@{
        SizeGB      = [Math]::Round($SizeBytes / 1GB, 1)
        FreeGB      = [Math]::Round($FreeBytes / 1GB, 1)
        PercentFree = $percentFree
        Status      = $status
    }
}

# ===========================================================================
# Active Directory functions (run on DC01 or a PC with RSAT)
# ===========================================================================

function Assert-ADModule {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw 'The ActiveDirectory module is not installed. Run this on DC01, or install RSAT: Active Directory tools.'
    }
    Import-Module ActiveDirectory -ErrorAction Stop
}

function New-BulkADUser {
    <#
    .SYNOPSIS
        Creates AD accounts from a CSV (FirstName, LastName, Role, School,
        Title, IdNumber). Each user goes to their role's OU and role group,
        gets a random temporary password, and must change it at first sign-in.
    .DESCRIPTION
        Bad rows are skipped and reported. Temporary passwords are saved to a
        CSV (ResultPath) so they can be handed out; delete that file after.
    .EXAMPLE
        New-BulkADUser -CsvPath .\data\new-users.csv -WhatIf
    .EXAMPLE
        New-BulkADUser -CsvPath .\data\new-users.csv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string] $CsvPath,

        [string] $ResultPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) `
            ('new-users-{0:yyyyMMdd-HHmmss}.csv' -f (Get-Date)))
    )

    Assert-ADModule
    $domain = Get-ADDomain
    $rows   = @(Import-Csv -Path $CsvPath -Encoding UTF8)
    if ($rows.Count -eq 0) { throw "$CsvPath has no rows." }

    $taken = New-Object System.Collections.Generic.List[string]
    Get-ADUser -Filter * | ForEach-Object { $taken.Add($_.SamAccountName) }

    $results = foreach ($row in $rows) {
        $display  = ('{0} {1}' -f (Get-RowValue $row 'FirstName'), (Get-RowValue $row 'LastName')).Trim()
        $problems = @(Test-PcusdUserRow -Row $row)
        if ($problems.Count -gt 0) {
            [pscustomobject]@{ Name = $display; Username = ''; Status = 'Skipped'
                               Detail = ($problems -join '; '); TempPassword = '' }
            continue
        }

        $role      = Get-RowValue $row 'Role'
        $firstName = Get-RowValue $row 'FirstName'
        $lastName  = Get-RowValue $row 'LastName'
        $settings  = Get-PcusdRoleSettings -Role $role
        $sam       = ConvertTo-PcusdUsername -FirstName $firstName -LastName $lastName -ExistingNames $taken
        $taken.Add($sam)
        $ou = '{0},{1}' -f $settings.OU, $domain.DistinguishedName

        if ($PSCmdlet.ShouldProcess("$display ($sam) in $ou", 'Create AD user')) {
            try {
                # The object name must be unique inside its OU; add the username if it isn't
                $cn = $display
                $escaped = $display.Replace("'", "''")
                if (Get-ADUser -Filter "Name -eq '$escaped'" -SearchBase $ou -SearchScope OneLevel) {
                    $cn = "$display ($sam)"
                }

                $plain = New-PcusdTempPassword
                $userParams = @{
                    Name                  = $cn
                    GivenName             = $firstName
                    Surname               = $lastName
                    DisplayName           = $display
                    SamAccountName        = $sam
                    UserPrincipalName     = "$sam@$($domain.DNSRoot)"
                    Path                  = $ou
                    Department            = $role
                    AccountPassword       = (ConvertTo-SecureString -String $plain -AsPlainText -Force)
                    ChangePasswordAtLogon = $true
                    Enabled               = $true
                }
                $title  = Get-RowValue $row 'Title'
                $school = Get-RowValue $row 'School'
                $idNum  = Get-RowValue $row 'IdNumber'
                if ($title)  { $userParams.Title      = $title }
                if ($school) { $userParams.Office     = $school }
                if ($idNum)  { $userParams.EmployeeID = $idNum }

                New-ADUser @userParams
                Add-ADGroupMember -Identity $settings.Group -Members $sam
                [pscustomobject]@{ Name = $display; Username = $sam; Status = 'Created'
                                   Detail = $ou; TempPassword = $plain }
            }
            catch {
                [pscustomobject]@{ Name = $display; Username = $sam; Status = 'Failed'
                                   Detail = $_.Exception.Message; TempPassword = '' }
            }
        }
        else {
            [pscustomobject]@{ Name = $display; Username = $sam; Status = 'WhatIf'
                               Detail = $ou; TempPassword = '' }
        }
    }

    $created = @($results | Where-Object Status -eq 'Created')
    if ($created.Count -gt 0) {
        $created | Select-Object Name, Username, TempPassword | Export-Csv -Path $ResultPath -NoTypeInformation
        Write-Warning "Temporary passwords saved to $ResultPath. Hand them out securely, then delete the file."
    }

    # Return results without passwords so they don't end up on screen or in logs
    $results | Select-Object Name, Username, Status, Detail
}

function Get-PasswordExpiryReport {
    <#
    .SYNOPSIS
        Enabled users whose passwords expire within the next N days (or
        already have, or must be changed at next sign-in).
    .EXAMPLE
        Get-PasswordExpiryReport -Days 14 | Export-Csv expiring.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 365)] [int] $Days = 14,
        [string] $SearchBase
    )

    Assert-ADModule
    if (-not $SearchBase) { $SearchBase = (Get-ADDomain).DistinguishedName }
    $now = Get-Date

    Get-ADUser -Filter 'Enabled -eq $true -and PasswordNeverExpires -eq $false' -SearchBase $SearchBase `
        -Properties 'msDS-UserPasswordExpiryTimeComputed', 'EmailAddress' |
        ForEach-Object {
            $raw = $_.'msDS-UserPasswordExpiryTimeComputed'
            if ($null -eq $raw) { return }
            $info = Get-PasswordExpiryStatus -ExpiryFileTime ([Int64]$raw) -Now $now
            if ($info -and $info.DaysLeft -le $Days) {
                [pscustomobject]@{
                    Name     = $_.Name
                    Username = $_.SamAccountName
                    Expires  = $info.Expires
                    DaysLeft = $info.DaysLeft
                    Status   = $info.Status
                    Email    = $_.EmailAddress
                }
            }
        } |
        Sort-Object DaysLeft
}

function Get-InactiveUserReport {
    <#
    .SYNOPSIS
        Enabled accounts with no sign-in for N days. Accounts created in the
        last N days are left out, so new hires who haven't signed in yet
        aren't flagged.
    .NOTES
        Uses lastLogonTimestamp, which AD updates only every 9-14 days, so
        use 30 days or more.
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(30, 3650)] [int] $Days = 90,
        [string] $SearchBase
    )

    Assert-ADModule
    if (-not $SearchBase) { $SearchBase = (Get-ADDomain).DistinguishedName }
    $cutoff = (Get-Date).AddDays(-$Days)

    Search-ADAccount -AccountInactive -TimeSpan (New-TimeSpan -Days $Days) -UsersOnly -SearchBase $SearchBase |
        Where-Object Enabled |
        ForEach-Object { Get-ADUser -Identity $_.DistinguishedName -Properties whenCreated, LastLogonDate, Description } |
        Where-Object { $_.whenCreated -lt $cutoff } |
        Select-Object Name, SamAccountName, LastLogonDate, whenCreated, DistinguishedName |
        Sort-Object LastLogonDate
}

function Disable-InactiveUser {
    <#
    .SYNOPSIS
        Disables inactive accounts, notes why in Description, and moves them
        to OU=Disabled Accounts. Use -WhatIf first.
    .EXAMPLE
        Disable-InactiveUser -Days 120 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [ValidateRange(30, 3650)] [int] $Days = 90,
        [string] $SearchBase,
        [string] $DisabledOU
    )

    Assert-ADModule
    $domainDN = (Get-ADDomain).DistinguishedName
    if (-not $SearchBase) { $SearchBase = "OU=PCUSD,$domainDN" }
    if (-not $DisabledOU) { $DisabledOU = "OU=Disabled Accounts,OU=PCUSD,$domainDN" }
    $stamp = Get-Date -Format 'yyyy-MM-dd'

    foreach ($user in @(Get-InactiveUserReport -Days $Days -SearchBase $SearchBase)) {
        if ($user.DistinguishedName -like "*,$DisabledOU") { continue }
        if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Disable and move to $DisabledOU")) {
            Disable-ADAccount -Identity $user.DistinguishedName
            Set-ADUser -Identity $user.DistinguishedName -Description "Disabled $stamp - inactive $Days+ days"
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $DisabledOU
            [pscustomobject]@{ Username = $user.SamAccountName; LastLogonDate = $user.LastLogonDate; Action = 'Disabled' }
        }
    }
}

function Reset-HelpDeskPassword {
    <#
    .SYNOPSIS
        Help desk password reset: unlocks the account, sets a random temporary
        password, forces a change at next sign-in, and logs the ticket.
    .DESCRIPTION
        Verify the caller's identity before running this. The temporary
        password is shown once on screen and is not written to the log.
    .EXAMPLE
        Reset-HelpDeskPassword -Identity jayden.nguyen -TicketNumber HD-1002
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Identity,
        [Parameter(Mandatory)] [ValidatePattern('^HD-\d+$')] [string] $TicketNumber,
        [string] $LogPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'helpdesk-password-resets.csv')
    )

    Assert-ADModule
    $user = Get-ADUser -Identity $Identity -Properties LockedOut

    if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Unlock and reset password')) {
        $plain = New-PcusdTempPassword
        if ($user.LockedOut) { Unlock-ADAccount -Identity $user }
        Set-ADAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString -String $plain -AsPlainText -Force)
        Set-ADUser -Identity $user -ChangePasswordAtLogon $true

        [pscustomobject]@{
            Date         = Get-Date -Format 'yyyy-MM-dd HH:mm'
            Ticket       = $TicketNumber
            User         = $user.SamAccountName
            WasLockedOut = [bool]$user.LockedOut
            Technician   = $env:USERNAME
        } | Export-Csv -Path $LogPath -Append -NoTypeInformation

        Write-Host "Temporary password for $($user.SamAccountName): $plain" -ForegroundColor Yellow
        Write-Host 'Read it to the verified user. They must change it at next sign-in.'
    }
}

# ===========================================================================
# Works on any Windows PC (no AD needed)
# ===========================================================================

function Get-SystemHealthReport {
    <#
    .SYNOPSIS
        Health check of this Windows PC: OS, uptime, memory, disks, pending
        restart, stopped automatic services, recent system errors, installed
        programs. Saves an HTML report and returns a summary object.
    .EXAMPLE
        Get-SystemHealthReport -OutputPath "$env:USERPROFILE\Desktop\health.html"
    #>
    [CmdletBinding()]
    param(
        [string] $OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) `
            ('health-{0}-{1:yyyyMMdd-HHmm}.html' -f $env:COMPUTERNAME, (Get-Date))),
        [ValidateRange(1, 99)] [int] $DiskWarnPercent = 15
    )

    $os       = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu      = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $uptime   = (Get-Date) - $os.LastBootUpTime
    $memTotal = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)   # KB -> GB
    $memFree  = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)

    $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object { $_.Size -gt 0 } | ForEach-Object {
        $status = Get-DiskStatus -SizeBytes $_.Size -FreeBytes $_.FreeSpace -WarnPercent $DiskWarnPercent
        [pscustomobject]@{ Drive = $_.DeviceID; SizeGB = $status.SizeGB; FreeGB = $status.FreeGB
                           PercentFree = $status.PercentFree; Status = $status.Status }
    })

    $rebootReasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $rebootReasons += 'Windows component update'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $rebootReasons += 'Windows Update'
    }
    $pendingRename = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pendingRename) { $rebootReasons += 'Pending file operations' }

    $stoppedServices = @(Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
        Select-Object @{ n = 'Service'; e = { $_.DisplayName } }, @{ n = 'Name'; e = { $_.Name } }, State)

    $recentErrors = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } `
        -MaxEvents 15 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, ProviderName, Id, @{ n = 'Message'; e = { ($_.Message -split "`n")[0] } })

    $uninstallKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $programCount = @(Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName }).Count

    $warnings = @()
    foreach ($disk in $disks) { if ($disk.Status -ne 'OK') { $warnings += "Drive $($disk.Drive) is $($disk.Status): $($disk.PercentFree)% free" } }
    if ($rebootReasons.Count -gt 0) { $warnings += "Restart pending: $($rebootReasons -join ', ')" }
    if ($uptime.TotalDays -gt 30)   { $warnings += "Up for $([int]$uptime.TotalDays) days; schedule a restart" }
    if ($memTotal -gt 0 -and ($memFree / $memTotal) -lt 0.10) { $warnings += "Low free memory: $memFree GB of $memTotal GB" }

    $summary = [pscustomobject]@{
        Computer          = $env:COMPUTERNAME
        OS                = $os.Caption
        Version           = $os.Version
        CPU               = $cpu.Name.Trim()
        LastBoot          = $os.LastBootUpTime
        UptimeDays        = [Math]::Round($uptime.TotalDays, 1)
        MemoryGB          = $memTotal
        MemoryFreeGB      = $memFree
        RestartPending    = ($rebootReasons.Count -gt 0)
        StoppedAutoServices = $stoppedServices.Count
        SystemErrors24h   = $recentErrors.Count
        InstalledPrograms = $programCount
        Warnings          = $warnings
    }

    $style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }
h1 { color: #1f3864; } h2 { color: #2e5c8a; margin-top: 28px; }
table { border-collapse: collapse; margin-top: 8px; }
th, td { border: 1px solid #ccc; padding: 4px 10px; text-align: left; font-size: 13px; }
th { background: #eef2f7; }
.warn { color: #9c2a00; font-weight: 600; }
</style>
'@
    $warningHtml = if ($warnings.Count -gt 0) {
        '<ul>' + (($warnings | ForEach-Object { "<li class='warn'>$([System.Net.WebUtility]::HtmlEncode($_))</li>" }) -join '') + '</ul>'
    } else { '<p>No warnings.</p>' }

    $body = @(
        "<h1>System health: $env:COMPUTERNAME</h1><p>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>"
        '<h2>Warnings</h2>' + $warningHtml
        ($summary | Select-Object Computer, OS, Version, CPU, LastBoot, UptimeDays, MemoryGB, MemoryFreeGB,
            RestartPending, StoppedAutoServices, SystemErrors24h, InstalledPrograms |
            ConvertTo-Html -As List -Fragment -PreContent '<h2>Summary</h2>' | Out-String)
        ($disks | ConvertTo-Html -Fragment -PreContent '<h2>Disks</h2>' | Out-String)
        ($stoppedServices | ConvertTo-Html -Fragment -PreContent '<h2>Automatic services not running</h2>' | Out-String)
        ($recentErrors | ConvertTo-Html -Fragment -PreContent '<h2>System errors in the last 24 hours</h2>' | Out-String)
    ) -join "`n"

    ConvertTo-Html -Head $style -Body $body -Title "Health - $env:COMPUTERNAME" | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Host "Report saved to $OutputPath"
    return $summary
}

Export-ModuleMember -Function @(
    'ConvertTo-PcusdUsername', 'New-PcusdTempPassword', 'Test-PcusdUserRow', 'Get-PcusdRoleSettings',
    'Get-PasswordExpiryStatus', 'Get-DiskStatus',
    'New-BulkADUser', 'Get-PasswordExpiryReport', 'Get-InactiveUserReport', 'Disable-InactiveUser',
    'Reset-HelpDeskPassword', 'Get-SystemHealthReport'
)
