<#
.SYNOPSIS
    Runs the PC health report and opens it in the browser.

.DESCRIPTION
    Works on any Windows PC; no Active Directory needed. Try it on your own
    computer first. Some checks (event log, services) show more when run as
    Administrator.

.EXAMPLE
    .\scripts\Invoke-HealthReport.ps1
#>
param(
    [string] $OutputFolder = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\AdminTools\AdminTools.psd1') -Force

$path = Join-Path $OutputFolder ('health-{0}-{1:yyyyMMdd-HHmm}.html' -f $env:COMPUTERNAME, (Get-Date))
$summary = Get-SystemHealthReport -OutputPath $path

$summary | Select-Object Computer, OS, UptimeDays, MemoryGB, MemoryFreeGB, RestartPending,
    StoppedAutoServices, SystemErrors24h, InstalledPrograms | Format-List

if ($summary.Warnings.Count -gt 0) {
    Write-Host 'Warnings:' -ForegroundColor Yellow
    $summary.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host 'No warnings.' -ForegroundColor Green
}

Invoke-Item -Path $path
