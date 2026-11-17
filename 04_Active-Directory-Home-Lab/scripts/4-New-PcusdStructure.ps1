#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Step 4 - Create the district's OUs and security groups, plus a personal
    admin account.

.DESCRIPTION
    Run on DC01 as PCUSD\Administrator. Safe to run more than once: anything
    that already exists is skipped.

    OU layout                          Groups (in OU=Groups)
    PCUSD                              Role groups (global):
      Staff                              GG-Teachers, GG-Office, GG-IT, GG-Students
        Teachers / Office / IT         Permission groups (domain local):
      Students                           DL-Staff-Share-Modify
      Computers                          DL-Students-Share-Read
        Staff Computers                  DL-Students-Share-Modify
        Student Computers                DL-IT-Share-Modify
      Groups
      Disabled Accounts

    Role groups go inside permission groups (AGDLP): Accounts -> Global
    groups -> Domain Local groups -> Permissions. To give all teachers access
    to something, you change one group membership, not 50 folder permissions.

.EXAMPLE
    .\4-New-PcusdStructure.ps1
#>
param(
    [string] $AdminSam = 'gavin.admin'
)

$ErrorActionPreference = 'Stop'
$domain   = Get-ADDomain
$domainDN = $domain.DistinguishedName
$netbios  = $domain.NetBIOSName

function New-OUIfMissing {
    param([string] $Name, [string] $Path)
    $dn = "OU=$Name,$Path"
    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel
    if (-not $existing) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "Created OU  $dn"
    }
    return $dn
}

function New-GroupIfMissing {
    param([string] $Name, [string] $Scope, [string] $Path, [string] $Description)
    if (-not (Get-ADGroup -Filter "Name -eq '$Name'")) {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope -GroupCategory Security `
            -Path $Path -Description $Description
        Write-Host "Created group $Name ($Scope)"
    }
}

# ---- OUs ----------------------------------------------------------------
$root      = New-OUIfMissing -Name 'PCUSD' -Path $domainDN
$staff     = New-OUIfMissing -Name 'Staff' -Path $root
foreach ($ou in 'Teachers', 'Office', 'IT') { New-OUIfMissing -Name $ou -Path $staff | Out-Null }
New-OUIfMissing -Name 'Students' -Path $root | Out-Null
$computers = New-OUIfMissing -Name 'Computers' -Path $root
foreach ($ou in 'Staff Computers', 'Student Computers') { New-OUIfMissing -Name $ou -Path $computers | Out-Null }
$groupsOU  = New-OUIfMissing -Name 'Groups' -Path $root
New-OUIfMissing -Name 'Disabled Accounts' -Path $root | Out-Null

# ---- Groups -------------------------------------------------------------
$roleGroups = @{
    'GG-Teachers' = 'All teachers'
    'GG-Office'   = 'School and district office staff'
    'GG-IT'       = 'IT department'
    'GG-Students' = 'All students'
}
foreach ($name in $roleGroups.Keys) {
    New-GroupIfMissing -Name $name -Scope Global -Path $groupsOU -Description $roleGroups[$name]
}

$permissionGroups = @{
    'DL-Staff-Share-Modify'    = 'Modify access to \\DC01\Staff'
    'DL-Students-Share-Read'   = 'Read access to \\DC01\Students'
    'DL-Students-Share-Modify' = 'Modify access to \\DC01\Students'
    'DL-IT-Share-Modify'       = 'Modify access to \\DC01\IT'
}
foreach ($name in $permissionGroups.Keys) {
    New-GroupIfMissing -Name $name -Scope DomainLocal -Path $groupsOU -Description $permissionGroups[$name]
}

# Nest role groups into permission groups (AGDLP)
$nesting = @{
    'DL-Staff-Share-Modify'    = @('GG-Teachers', 'GG-Office', 'GG-IT')
    'DL-Students-Share-Read'   = @('GG-Students')
    'DL-Students-Share-Modify' = @('GG-Teachers')
    'DL-IT-Share-Modify'       = @('GG-IT')
}
foreach ($dl in $nesting.Keys) {
    $current = @(Get-ADGroupMember -Identity $dl | Select-Object -ExpandProperty SamAccountName)
    $toAdd   = @($nesting[$dl] | Where-Object { $_ -notin $current })
    if ($toAdd.Count -gt 0) {
        Add-ADGroupMember -Identity $dl -Members $toAdd
    }
}
Write-Host 'Group nesting set.'

# ---- Personal admin account --------------------------------------------
# Day-to-day work uses a normal account; admin work uses a separate admin account.
if (-not (Get-ADUser -Filter "SamAccountName -eq '$AdminSam'")) {
    $pw = Read-Host -AsSecureString -Prompt "Password for $netbios\$AdminSam"
    New-ADUser -Name 'Gavin Gementera (Admin)' -SamAccountName $AdminSam `
        -UserPrincipalName "$AdminSam@$($domain.DNSRoot)" -Path "OU=IT,$staff" `
        -AccountPassword $pw -Enabled $true -Description 'Personal admin account'
    Add-ADGroupMember -Identity 'Domain Admins' -Members $AdminSam
    Add-ADGroupMember -Identity 'GG-IT' -Members $AdminSam
    Write-Host "Created $netbios\$AdminSam and added it to Domain Admins"
}

Write-Host ''
Get-ADOrganizationalUnit -Filter * -SearchBase $root |
    Sort-Object DistinguishedName | Format-Table Name, DistinguishedName -AutoSize
