#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Checks the whole lab and reports PASS / WARN / FAIL for each part, with
    a hint on how to fix anything that isn't right.

.DESCRIPTION
    Run on DC01 as PCUSD\gavin.admin after you finish each step. Checks that
    don't apply yet (for example file shares before step 7) show as FAIL
    with the step that sets them up, so you can use this as a progress
    checker too.

    Saves an HTML report to your Desktop. A screenshot of an all-PASS
    report is good evidence for the portfolio.

.EXAMPLE
    .\7-Test-LabHealth.ps1
#>
param(
    [string] $DomainName = 'pcusd.internal',
    [string] $DcIP       = '10.0.10.10',
    [string] $ScopeId    = '10.0.10.0',
    [string] $Client     = 'CLIENT01',
    [string] $ReportPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) ('lab-health-{0:yyyyMMdd-HHmm}.html' -f (Get-Date)))
)

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string] $Area, [string] $Check, [ValidateSet('PASS', 'WARN', 'FAIL')] [string] $Status, [string] $Detail, [string] $Fix = '')
    $results.Add([pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail; Fix = $Fix })
}

function Test-Step {
    # Runs one check; any error becomes a FAIL instead of stopping the script
    param([string] $Area, [string] $Check, [string] $Fix, [scriptblock] $Test)
    try {
        $outcome = & $Test
        if ($outcome -is [array]) { $outcome = $outcome[-1] }
        if ($outcome.Status -ne 'PASS') { $fixText = $Fix } else { $fixText = '' }
        Add-Result -Area $Area -Check $Check -Status $outcome.Status -Detail $outcome.Detail -Fix $fixText
    }
    catch {
        Add-Result -Area $Area -Check $Check -Status 'FAIL' -Detail $_.Exception.Message -Fix $Fix
    }
}

function Result([bool] $Ok, [string] $Detail, [switch] $WarnOnly) {
    if ($Ok) { $status = 'PASS' } elseif ($WarnOnly) { $status = 'WARN' } else { $status = 'FAIL' }
    [pscustomobject]@{ Status = $status; Detail = $Detail }
}

$domainDN = 'DC=' + ($DomainName -split '\.' -join ',DC=')
$root     = "OU=PCUSD,$domainDN"
$fqdn     = "$env:COMPUTERNAME.$DomainName".ToLower()

# ===================================================================== server
Test-Step 'Server' 'Computer name is DC01' 'Step 3.1: 1-Set-DC01Network.ps1' {
    Result ($env:COMPUTERNAME -eq 'DC01') "Name: $env:COMPUTERNAME"
}
Test-Step 'Server' "Static IP $DcIP" 'Step 3.1: 1-Set-DC01Network.ps1' {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object IPAddress -eq $DcIP
    $static = $ip -and $ip.PrefixOrigin -eq 'Manual'
    Result $static ($(if ($ip) { "$DcIP ($($ip.PrefixOrigin))" } else { "$DcIP not found on any adapter" }))
}
Test-Step 'Server' 'Windows is activated' 'Settings > System > Activation (the evaluation shuts down if not activated within 10 days)' {
    $lic = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" |
        Select-Object -First 1
    Result ($lic.LicenseStatus -eq 1) "License status code: $($lic.LicenseStatus) (1 = licensed)" -WarnOnly
}
Test-Step 'Server' 'Windows Time service running' 'Start-Service W32Time. Kerberos sign-in fails if clocks differ by more than 5 minutes' {
    $t = Get-Service -Name W32Time -ErrorAction Stop
    $out = w32tm /query /status 2>&1 | Out-String
    $source = (($out -split "`r?`n" | Where-Object { $_ -match '^Source:' }) -join '').Trim()
    Result ($t.Status -eq 'Running') "W32Time is $($t.Status). $source" -WarnOnly
}

# ================================================================ AD services
foreach ($svc in @(
        @{ Name = 'NTDS';     Label = 'Active Directory Domain Services' },
        @{ Name = 'DNS';      Label = 'DNS Server' },
        @{ Name = 'Kdc';      Label = 'Kerberos Key Distribution Center' },
        @{ Name = 'Netlogon'; Label = 'Netlogon' },
        @{ Name = 'DFSR';     Label = 'DFS Replication (SYSVOL)' })) {
    $name = $svc.Name
    Test-Step 'Services' "$($svc.Label) running" 'Step 3.2: 2-Install-ADForest.ps1, or restart the service' {
        $s = Get-Service -Name $name -ErrorAction Stop
        Result ($s.Status -eq 'Running') "$name is $($s.Status)"
    }
}

# ===================================================================== domain
Test-Step 'Domain' "Domain is $DomainName" 'Step 3.2: 2-Install-ADForest.ps1' {
    $d = Get-ADDomain -ErrorAction Stop
    Result ($d.DNSRoot -eq $DomainName) "DNSRoot $($d.DNSRoot), NetBIOS $($d.NetBIOSName), PDC $($d.PDCEmulator)"
}
Test-Step 'Domain' 'SYSVOL and NETLOGON are shared' 'Wait a few minutes after promotion and restart; check the DFSR event log' {
    $shares = (Get-SmbShare -ErrorAction Stop).Name
    Result (($shares -contains 'SYSVOL') -and ($shares -contains 'NETLOGON')) ("Shares: " + ($shares -join ', '))
}

# ======================================================================== DNS
Test-Step 'DNS' 'Domain controller SRV record' 'Restart Netlogon (it re-registers the records): Restart-Service Netlogon' {
    $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -Server 127.0.0.1 -ErrorAction Stop |
        Where-Object { $_.Type -eq 'SRV' }
    Result ([bool]$srv) ("Targets: " + (($srv.NameTarget | Sort-Object -Unique) -join ', '))
}
Test-Step 'DNS' 'Forwarders set' 'Step 3.3: 3-Set-DnsAndDhcp.ps1' {
    $f = (Get-DnsServerForwarder -ErrorAction Stop).IPAddress.IPAddressToString
    Result ([bool]$f) ("Forwarders: " + ($f -join ', '))
}
Test-Step 'DNS' 'Reverse lookup zone' 'Step 3.3: 3-Set-DnsAndDhcp.ps1' {
    $z = Get-DnsServerZone -ErrorAction Stop | Where-Object { $_.IsReverseLookupZone -and $_.ZoneName -like '*10.0.10*' }
    Result ([bool]$z) ($(if ($z) { $z.ZoneName } else { 'No 10.0.10.x reverse zone' })) -WarnOnly
}
Test-Step 'DNS' 'Internet names resolve' 'Check forwarders and the VirtualBox NAT Network' {
    $r = Resolve-DnsName -Name 'www.microsoft.com' -Server 127.0.0.1 -DnsOnly -ErrorAction Stop |
        Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
    Result ([bool]$r) ($(if ($r) { "www.microsoft.com -> $($r.IPAddress)" } else { 'No A record returned' }))
}

# ======================================================================= DHCP
Test-Step 'DHCP' 'Server authorized in AD' 'DHCP console > right-click the server > Authorize, or step 3.3' {
    $auth = Get-DhcpServerInDC -ErrorAction Stop | Where-Object { $_.DnsName -eq $fqdn -or $_.IPAddress -eq $DcIP }
    Result ([bool]$auth) ($(if ($auth) { "Authorized as $($auth.DnsName)" } else { 'Not authorized' }))
}
Test-Step 'DHCP' 'Scope active' 'Step 3.3: 3-Set-DnsAndDhcp.ps1' {
    $s = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction Stop
    Result ($s.State -eq 'Active') "$($s.StartRange) - $($s.EndRange), $($s.State)"
}
Test-Step 'DHCP' 'Scope gives out DC01 as DNS' 'Set-DhcpServerv4OptionValue -ScopeId 10.0.10.0 -DnsServer 10.0.10.10' {
    $opt = Get-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 6 -ErrorAction Stop
    Result ($opt.Value -contains $DcIP) ("Option 6 (DNS): " + ($opt.Value -join ', '))
}
Test-Step 'DHCP' 'Leases handed out' 'Start CLIENT01; it should get an address within a minute' {
    $leases = @(Get-DhcpServerv4Lease -ScopeId $ScopeId -ErrorAction Stop)
    $detail = if ($leases.Count) { "$($leases.Count) lease(s): " + (($leases | ForEach-Object { "$($_.HostName) $($_.IPAddress)" }) -join '; ') } else { 'No leases yet' }
    Result ($leases.Count -gt 0) $detail -WarnOnly
}

# ============================================================ OUs and groups
$ous = 'PCUSD', 'Staff,OU=PCUSD', 'Teachers,OU=Staff,OU=PCUSD', 'Office,OU=Staff,OU=PCUSD', 'IT,OU=Staff,OU=PCUSD',
       'Students,OU=PCUSD', 'Computers,OU=PCUSD', 'Staff Computers,OU=Computers,OU=PCUSD',
       'Student Computers,OU=Computers,OU=PCUSD', 'Groups,OU=PCUSD', 'Disabled Accounts,OU=PCUSD'
Test-Step 'Structure' "All $($ous.Count) OUs exist" 'Step 4.1: 4-New-PcusdStructure.ps1' {
    $missing = @(foreach ($ou in $ous) {
        $dn = "OU=$ou,$domainDN"
        try { Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop | Out-Null } catch { ($ou -split ',')[0] }
    })
    Result ($missing.Count -eq 0) ($(if ($missing) { 'Missing: ' + ($missing -join ', ') } else { 'All present' }))
}
$nesting = @{
    'DL-Staff-Share-Modify'    = @('GG-Teachers', 'GG-Office', 'GG-IT')
    'DL-Students-Share-Read'   = @('GG-Students')
    'DL-Students-Share-Modify' = @('GG-Teachers')
    'DL-IT-Share-Modify'       = @('GG-IT')
}
Test-Step 'Structure' 'Groups exist and are nested (AGDLP)' 'Step 4.1: 4-New-PcusdStructure.ps1' {
    $problems = @(foreach ($dl in $nesting.Keys) {
        try {
            $members = @(Get-ADGroupMember -Identity $dl -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
            foreach ($gg in $nesting[$dl]) { if ($members -notcontains $gg) { "$gg not in $dl" } }
        } catch { "$dl missing" }
    })
    Result ($problems.Count -eq 0) ($(if ($problems) { $problems -join '; ' } else { '4 permission groups, nesting correct' }))
}
Test-Step 'Structure' 'Personal admin account' 'Step 4.1 creates PCUSD\gavin.admin' {
    $admins = @(Get-ADGroupMember -Identity 'Domain Admins' -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
    Result ($admins -contains 'gavin.admin') ("Domain Admins: " + ($admins -join ', '))
}

# ====================================================================== users
Test-Step 'Users' 'Users created in the PCUSD OUs' 'Step 4.2: New-BulkADUser -CsvPath .\data\new-users.csv' {
    $users = @(Get-ADUser -Filter * -SearchBase $root -ErrorAction Stop | Where-Object { $_.SamAccountName -ne 'gavin.admin' })
    $byOu = $users | Group-Object { ($_.DistinguishedName -split ',')[1] -replace '^OU=', '' } |
        ForEach-Object { "$($_.Name -replace 'OU=', ''): $($_.Count)" }
    Result ($users.Count -ge 20) ("$($users.Count) users. " + ($byOu -join ' | '))
}
Test-Step 'Users' 'Every user is in their role group' 'Add missing users to GG-Teachers / GG-Office / GG-IT / GG-Students' {
    $map = @{ 'Teachers' = 'GG-Teachers'; 'Office' = 'GG-Office'; 'IT' = 'GG-IT'; 'Students' = 'GG-Students' }
    $missing = @(foreach ($ou in $map.Keys) {
        $path = if ($ou -eq 'Students') { "OU=Students,$root" } else { "OU=$ou,OU=Staff,$root" }
        $members = @(Get-ADGroupMember -Identity $map[$ou] -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
        Get-ADUser -Filter * -SearchBase $path -SearchScope OneLevel -ErrorAction Stop |
            Where-Object { $_.SamAccountName -ne 'gavin.admin' -and $members -notcontains $_.SamAccountName } |
            ForEach-Object { "$($_.SamAccountName) not in $($map[$ou])" }
    })
    Result ($missing.Count -eq 0) ($(if ($missing) { $missing -join '; ' } else { 'All users are in their role group' }))
}
Test-Step 'Users' 'Locked-out accounts' 'Unlock-ADAccount -Identity <user> (see docs/08)' {
    $locked = @(Search-ADAccount -LockedOut -UsersOnly -ErrorAction Stop)
    Result ($locked.Count -eq 0) ($(if ($locked) { 'Locked: ' + ($locked.SamAccountName -join ', ') } else { 'None' })) -WarnOnly
}

# ============================================================ Group Policy
Test-Step 'Policy' 'Password and lockout policy' 'Step 6.1: 6-New-PcusdGPOs.ps1' {
    $p = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
    $ok = $p.MinPasswordLength -ge 12 -and $p.LockoutThreshold -eq 5 -and $p.ComplexityEnabled
    Result $ok "Min length $($p.MinPasswordLength), complexity $($p.ComplexityEnabled), lockout after $($p.LockoutThreshold) for $($p.LockoutDuration)"
}
$gpoLinks = [ordered]@{
    'PCUSD - Students - Block Control Panel' = "OU=Students,$root"
    'PCUSD - Student Computers - Block USB'  = "OU=Student Computers,OU=Computers,$root"
    'PCUSD - All Computers - Logon Banner'   = "OU=Computers,$root"
    'PCUSD - Staff - Map S Drive'            = "OU=Staff,$root"
}
foreach ($gpoName in $gpoLinks.Keys) {
    $target = $gpoLinks[$gpoName]
    $fix = if ($gpoName -like '*Map S Drive') { 'Step 6.2 (made in the GUI)' } else { 'Step 6.1: 6-New-PcusdGPOs.ps1' }
    Test-Step 'Policy' "GPO linked: $gpoName" $fix {
        $links = (Get-GPInheritance -Target $target -ErrorAction Stop).GpoLinks
        $link = $links | Where-Object DisplayName -eq $gpoName
        Result ([bool]$link -and $link.Enabled) ($(if ($link) { "Linked to $(($target -split ',')[0])" } else { 'Not linked' }))
    }
}

# ============================================================== File shares
$shareChecks = [ordered]@{
    'Staff'    = @('DL-Staff-Share-Modify')
    'Students' = @('DL-Students-Share-Modify', 'DL-Students-Share-Read')
    'IT'       = @('DL-IT-Share-Modify')
}
foreach ($shareName in $shareChecks.Keys) {
    $groups = $shareChecks[$shareName]
    Test-Step 'Shares' "\\DC01\$shareName shared with permission groups" 'Step 7: 5-New-PcusdShares.ps1' {
        $share = Get-SmbShare -Name $shareName -ErrorAction Stop
        $acl = (Get-Acl -Path $share.Path).Access.IdentityReference.Value
        $missing = @($groups | Where-Object { $g = $_; -not ($acl | Where-Object { $_ -like "*\$g" }) })
        $inherits = -not (Get-Acl -Path $share.Path).AreAccessRulesProtected
        $ok = $missing.Count -eq 0 -and -not $inherits -and $share.FolderEnumerationMode -eq 'AccessBased'
        $detail = "Path $($share.Path); ABE $($share.FolderEnumerationMode); inheritance " +
                  $(if ($inherits) { 'ON (should be off)' } else { 'off' }) +
                  $(if ($missing) { "; missing NTFS entry for $($missing -join ', ')" } else { '' })
        Result $ok $detail
    }
}

# ===================================================================== client
Test-Step 'Client' "$Client joined to the domain" 'Step 5.2: join CLIENT01 to pcusd.internal' {
    $c = Get-ADComputer -Identity $Client -Properties LastLogonDate, OperatingSystem -ErrorAction Stop
    Result $true "$($c.OperatingSystem); last sign-in $($c.LastLogonDate)"
}
Test-Step 'Client' "$Client is in a PCUSD computers OU" 'Step 5.3: move it to Staff Computers or Student Computers' {
    $c = Get-ADComputer -Identity $Client -ErrorAction Stop
    $ou = ($c.DistinguishedName -split ',', 2)[1]
    Result ($ou -like "*OU=Computers,$root") "In $ou"
}
Test-Step 'Client' "$Client answers on the network" 'Start CLIENT01; check its IP with ipconfig and the Windows Firewall' {
    $ping = Test-Connection -ComputerName $Client -Count 1 -Quiet -ErrorAction SilentlyContinue
    Result ([bool]$ping) ($(if ($ping) { 'Ping OK' } else { 'No reply (it may be off, or the firewall blocks ping)' })) -WarnOnly
}

# ==================================================================== report
$pass = @($results | Where-Object Status -eq 'PASS').Count
$warn = @($results | Where-Object Status -eq 'WARN').Count
$fail = @($results | Where-Object Status -eq 'FAIL').Count

foreach ($r in $results) {
    $color = @{ PASS = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }[$r.Status]
    Write-Host ('[{0}] ' -f $r.Status) -ForegroundColor $color -NoNewline
    Write-Host ('{0,-9} {1}' -f $r.Area, $r.Check) -NoNewline
    Write-Host ("  - $($r.Detail)") -ForegroundColor DarkGray
    if ($r.Fix) { Write-Host "            Fix: $($r.Fix)" -ForegroundColor Cyan }
}
Write-Host ''
Write-Host "PASS $pass   WARN $warn   FAIL $fail" -ForegroundColor $(if ($fail) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })

$style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #1d2733; }
h1 { color: #1f3864; margin-bottom: 4px; } p.sub { color: #5f6b7a; margin-top: 0; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border-bottom: 1px solid #d9dee5; padding: 6px 10px; text-align: left; vertical-align: top; }
th { background: #eef2f7; }
td.PASS { color: #1e6b34; font-weight: 700; } td.WARN { color: #7a5a00; font-weight: 700; } td.FAIL { color: #a12a20; font-weight: 700; }
.summary span { display: inline-block; margin-right: 16px; font-weight: 700; }
</style>
'@
$rows = foreach ($r in $results) {
    $cells = foreach ($v in $r.Area, $r.Check, $r.Detail, $r.Fix) { [System.Net.WebUtility]::HtmlEncode([string]$v) }
    "<tr><td>$($cells[0])</td><td>$($cells[1])</td><td class='$($r.Status)'>$($r.Status)</td><td>$($cells[2])</td><td>$($cells[3])</td></tr>"
}
$html = @"
<html><head><meta charset='utf-8'><title>Lab health - $DomainName</title>$style</head><body>
<h1>Lab health check: $DomainName</h1>
<p class='sub'>Run on $env:COMPUTERNAME by $env:USERDOMAIN\$env:USERNAME, $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
<p class='summary'><span style='color:#1e6b34'>PASS $pass</span><span style='color:#7a5a00'>WARN $warn</span><span style='color:#a12a20'>FAIL $fail</span></p>
<table><tr><th>Area</th><th>Check</th><th>Result</th><th>Detail</th><th>How to fix</th></tr>
$($rows -join "`n")
</table></body></html>
"@
$html | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host "Report saved to $ReportPath"
