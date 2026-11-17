#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 3.2 - Install Active Directory Domain Services and DNS, and create the
    pcusd.internal forest with DC01 as its first domain controller.

.DESCRIPTION
    Run on DC01 (after 1-Set-DC01Network.ps1 and the restart), in PowerShell
    as Administrator. You'll be asked for the Directory Services Restore Mode
    (DSRM) password, the emergency password used to repair Active Directory.
    The server restarts on its own when promotion finishes; log back in as
    PCUSD\Administrator.

.EXAMPLE
    .\2-Install-ADForest.ps1
#>
param(
    [string] $DomainName  = 'pcusd.internal',
    [string] $NetbiosName = 'PCUSD'
)

$ErrorActionPreference = 'Stop'

if ($env:COMPUTERNAME -ne 'DC01') {
    Write-Warning "This computer is named $env:COMPUTERNAME. Run 1-Set-DC01Network.ps1 first so it's named DC01."
}

Write-Host 'Installing the AD DS and DNS roles (a few minutes)...'
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

$dsrm = Read-Host -AsSecureString -Prompt 'Choose a Directory Services Restore Mode (DSRM) password'

Write-Host "Creating forest $DomainName. The server will restart when it's done."
Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $NetbiosName `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrm `
    -Force
