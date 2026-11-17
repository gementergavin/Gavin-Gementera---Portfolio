#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Weekly account hygiene reports: passwords expiring in the next 14 days
    and accounts inactive for 90+ days. Saves both as CSV files.

.DESCRIPTION
    Run on DC01 (or a PC with RSAT) as an account that can read AD. This
    only reports; it changes nothing. To schedule it every Monday at 7 AM:

      $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
                   -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Tools\05_PowerShell-Admin-Toolkit\scripts\Invoke-WeeklyAccountReports.ps1'
      $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 7am
      Register-ScheduledTask -TaskName 'PCUSD Weekly Account Reports' -Action $action -Trigger $trigger `
          -User 'PCUSD\gavin.admin' -Password (Read-Host 'Password') -RunLevel Highest

.EXAMPLE
    .\scripts\Invoke-WeeklyAccountReports.ps1 -OutputFolder C:\Reports
#>
param(
    [string] $OutputFolder = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AccountReports'),
    [int]    $ExpiringDays = 14,
    [int]    $InactiveDays = 90
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\AdminTools\AdminTools.psd1') -Force
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd'

$expiring = @(Get-PasswordExpiryReport -Days $ExpiringDays)
$expiringPath = Join-Path $OutputFolder "passwords-expiring-$stamp.csv"
$expiring | Export-Csv -Path $expiringPath -NoTypeInformation

$inactive = @(Get-InactiveUserReport -Days $InactiveDays)
$inactivePath = Join-Path $OutputFolder "inactive-accounts-$stamp.csv"
$inactive | Export-Csv -Path $inactivePath -NoTypeInformation

Write-Host "Passwords expiring within $ExpiringDays days: $($expiring.Count)  -> $expiringPath"
Write-Host "Accounts inactive $InactiveDays+ days:         $($inactive.Count)  -> $inactivePath"
