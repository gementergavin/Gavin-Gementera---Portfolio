#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy
<#
.SYNOPSIS
    Step 6 - Domain password policy and three Group Policy Objects.

.DESCRIPTION
    Run on DC01 as an admin, after 4-New-PcusdStructure.ps1.

      Password policy (domain-wide): 12+ characters, complexity on,
        remember 10 passwords, lock out for 15 minutes after 5 wrong tries.
      PCUSD - Students - Block Control Panel     -> linked to OU=Students
      PCUSD - Student Computers - Block USB      -> linked to OU=Student Computers
      PCUSD - All Computers - Logon Banner       -> linked to OU=Computers

    The S: drive mapping for staff is done in the GUI (docs/06-group-policy.md)
    because Group Policy Preferences drive maps have no PowerShell cmdlet.

    Settings made with Set-GPRegistryValue show up in the GPO report under
    "Administrative Templates" or "Extra Registry Settings".

.EXAMPLE
    .\6-New-PcusdGPOs.ps1
#>

$ErrorActionPreference = 'Stop'
$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$root     = "OU=PCUSD,$domainDN"

# ---- Domain password and lockout policy --------------------------------
Set-ADDefaultDomainPasswordPolicy -Identity $domain.DNSRoot `
    -MinPasswordLength 12 `
    -ComplexityEnabled $true `
    -PasswordHistoryCount 10 `
    -MaxPasswordAge (New-TimeSpan -Days 180) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -LockoutThreshold 5 `
    -LockoutDuration (New-TimeSpan -Minutes 15) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15)
Write-Host 'Domain password and lockout policy set.'

function New-LinkedGpo {
    param([string] $Name, [string] $Comment, [string] $Target)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Name -Comment $Comment
        Write-Host "Created GPO '$Name'"
    }
    $linked = (Get-GPInheritance -Target $Target).GpoLinks | Where-Object DisplayName -eq $Name
    if (-not $linked) {
        New-GPLink -Name $Name -Target $Target | Out-Null
        Write-Host "  linked to $Target"
    }
    return $gpo
}

# ---- Students: no Control Panel or Settings app -------------------------
$gpo = New-LinkedGpo -Name 'PCUSD - Students - Block Control Panel' `
    -Comment 'User policy: students cannot open Control Panel or Settings.' `
    -Target "OU=Students,$root"
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
    -ValueName 'NoControlPanel' -Type DWord -Value 1 | Out-Null

# ---- Student computers: no USB storage ----------------------------------
$gpo = New-LinkedGpo -Name 'PCUSD - Student Computers - Block USB' `
    -Comment 'Computer policy: deny all removable storage on student computers.' `
    -Target "OU=Student Computers,OU=Computers,$root"
Set-GPRegistryValue -Guid $gpo.Id -Key 'HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices' `
    -ValueName 'Deny_All' -Type DWord -Value 1 | Out-Null

# ---- All district computers: logon banner -------------------------------
$gpo = New-LinkedGpo -Name 'PCUSD - All Computers - Logon Banner' `
    -Comment 'Computer policy: acceptable use notice before sign-in.' `
    -Target "OU=Computers,$root"
$bannerKey = 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System'
Set-GPRegistryValue -Guid $gpo.Id -Key $bannerKey -ValueName 'LegalNoticeCaption' -Type String `
    -Value 'Pacific Crest Unified School District' | Out-Null
Set-GPRegistryValue -Guid $gpo.Id -Key $bannerKey -ValueName 'LegalNoticeText' -Type String `
    -Value 'This computer is for authorized district use only. Activity may be monitored. By signing in you agree to the Acceptable Use Policy.' | Out-Null

Write-Host ''
Write-Host 'GPOs in the domain:'
Get-GPO -All | Where-Object DisplayName -like 'PCUSD*' | Format-Table DisplayName, GpoStatus, ModificationTime -AutoSize
