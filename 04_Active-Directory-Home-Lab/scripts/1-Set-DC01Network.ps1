#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 3.1 - Give DC01 a static IP address and its name.

.DESCRIPTION
    Run on the new Windows Server VM, in PowerShell as Administrator.
    A domain controller needs an address that never changes, because every
    computer in the domain finds it through DNS at that address.

    DNS is set to public resolvers for now so Windows can activate (the
    evaluation must activate within 10 days). Promoting the server to a
    domain controller in step 3.2 switches DNS to the server itself.

.EXAMPLE
    .\1-Set-DC01Network.ps1
#>
param(
    [string]   $ComputerName = 'DC01',
    [string]   $IPAddress    = '10.0.10.10',
    [int]      $PrefixLength = 24,
    [string]   $Gateway      = '10.0.10.1',
    [string[]] $TempDns      = @('1.1.1.1', '8.8.8.8')
)

$ErrorActionPreference = 'Stop'

$nic = Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $nic) {
    throw 'No connected network adapter found. Check that Adapter 1 is attached to the PCUSD-Lab NAT Network.'
}
Write-Host "Using network adapter '$($nic.Name)'"

# Clear any address and default route the adapter already has
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false
Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false

Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength `
    -DefaultGateway $Gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $TempDns

Write-Host "Static IP set: $IPAddress/$PrefixLength, gateway $Gateway, DNS $($TempDns -join ', ')"

$test = Test-NetConnection -ComputerName 'www.microsoft.com' -Port 443 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host 'Internet check: OK'
} else {
    Write-Warning 'Internet check failed. Check the NAT Network in VirtualBox before going on.'
}

if ($env:COMPUTERNAME -ne $ComputerName) {
    Write-Host "Renaming this computer to $ComputerName and restarting in 10 seconds..."
    Start-Sleep -Seconds 10
    Rename-Computer -NewName $ComputerName -Restart
}
