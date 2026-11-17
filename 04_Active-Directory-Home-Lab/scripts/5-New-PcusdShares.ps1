#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 7 - Create the Staff, Students and IT file shares with permissions
    granted to groups, not people.

.DESCRIPTION
    Run on DC01 as an admin, after 4-New-PcusdStructure.ps1.
    (In a real district the shares would live on a separate file server;
    in a two-VM lab they go on DC01.)

    Two layers of permissions protect a share:
      - Share permissions: Authenticated Users = Change, Administrators = Full.
        Kept broad on purpose.
      - NTFS permissions: the real control. Inheritance is turned off and
        only SYSTEM, Administrators and the DL- groups are granted access.
    Access-based enumeration hides folders a user can't open.

.EXAMPLE
    .\5-New-PcusdShares.ps1
#>
param(
    [string] $ShareRoot = 'C:\Shares'
)

$ErrorActionPreference = 'Stop'
$netbios = (Get-ADDomain).NetBIOSName

$shares = @(
    @{ Name = 'Staff';    Modify = @('DL-Staff-Share-Modify');    Read = @() }
    @{ Name = 'Students'; Modify = @('DL-Students-Share-Modify'); Read = @('DL-Students-Share-Read') }
    @{ Name = 'IT';       Modify = @('DL-IT-Share-Modify');       Read = @() }
)

foreach ($share in $shares) {
    $path = Join-Path $ShareRoot $share.Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null

    # NTFS: remove inherited entries, then grant only what's needed.
    # (OI)(CI) = applies to this folder, subfolders and files. M = Modify, RX = Read & execute.
    icacls $path /inheritance:r /grant:r 'NT AUTHORITY\SYSTEM:(OI)(CI)F' 'BUILTIN\Administrators:(OI)(CI)F' | Out-Null
    foreach ($group in $share.Modify) { icacls $path /grant:r "$netbios\${group}:(OI)(CI)M" | Out-Null }
    foreach ($group in $share.Read)   { icacls $path /grant:r "$netbios\${group}:(OI)(CI)RX" | Out-Null }

    if (-not (Get-SmbShare -Name $share.Name -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $share.Name -Path $path `
            -FullAccess 'BUILTIN\Administrators' -ChangeAccess 'NT AUTHORITY\Authenticated Users' `
            -FolderEnumerationMode AccessBased | Out-Null
        Write-Host "Shared $path as \\$env:COMPUTERNAME\$($share.Name)"
    }
}

Write-Host ''
foreach ($share in $shares) {
    Write-Host "NTFS permissions on $(Join-Path $ShareRoot $share.Name):"
    icacls (Join-Path $ShareRoot $share.Name)
}
