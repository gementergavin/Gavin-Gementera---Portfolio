#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 3.3 - Finish DNS and set up DHCP on DC01.

.DESCRIPTION
    Run on DC01 after promotion, logged in as PCUSD\Administrator.
      - DNS: forwards internet lookups to public resolvers and adds a reverse
        lookup zone, so IP addresses resolve back to names.
      - DHCP: installs the role, authorizes it in Active Directory, and creates
        a scope that hands out 10.0.10.100-200 with DC01 as the DNS server.
        Domain-joined PCs must use DC01 for DNS or they can't find the domain.

.EXAMPLE
    .\3-Set-DnsAndDhcp.ps1
#>
param(
    [string]   $DomainName = 'pcusd.internal',
    [string]   $DcIP       = '10.0.10.10',
    [string]   $ScopeId    = '10.0.10.0',
    [string]   $StartRange = '10.0.10.100',
    [string]   $EndRange   = '10.0.10.200',
    [string]   $SubnetMask = '255.255.255.0',
    [string]   $Gateway    = '10.0.10.1',
    [string[]] $Forwarders = @('1.1.1.1', '8.8.8.8')
)

$ErrorActionPreference = 'Stop'
$fqdn = "$env:COMPUTERNAME.$DomainName".ToLower()

# ---- DNS ----------------------------------------------------------------
Set-DnsServerForwarder -IPAddress $Forwarders
Write-Host "DNS forwarders: $($Forwarders -join ', ')"

$reverseZone = '10.0.10.in-addr.arpa'
if (-not (Get-DnsServerZone -Name $reverseZone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId '10.0.10.0/24' -ReplicationScope Domain
    Write-Host "Created reverse lookup zone $reverseZone"
}

# ---- DHCP ---------------------------------------------------------------
Write-Host 'Installing the DHCP role...'
Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null

# Create the local "DHCP Administrators" and "DHCP Users" groups
netsh dhcp add securitygroups | Out-Null
Restart-Service -Name DHCPServer

# A DHCP server in a domain must be authorized in AD before it hands out addresses
$authorized = Get-DhcpServerInDC | Where-Object { $_.DnsName -eq $fqdn }
if (-not $authorized) {
    Add-DhcpServerInDC -DnsName $fqdn -IPAddress $DcIP
    Write-Host "Authorized DHCP server $fqdn in Active Directory"
}

# Tell Server Manager the DHCP post-install steps are done (clears its warning flag)
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12' -Name ConfigurationState -Value 2

if (-not (Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Scope -Name 'PCUSD-Lab' -StartRange $StartRange -EndRange $EndRange `
        -SubnetMask $SubnetMask -LeaseDuration (New-TimeSpan -Days 1) -State Active
    Write-Host "Created DHCP scope $StartRange - $EndRange"
}
Set-DhcpServerv4OptionValue -ScopeId $ScopeId -Router $Gateway -DnsServer $DcIP -DnsDomain $DomainName

Write-Host ''
Write-Host 'Done. Checks:'
Get-DhcpServerv4Scope | Format-Table ScopeId, Name, StartRange, EndRange, State -AutoSize
Resolve-DnsName -Name 'www.microsoft.com' -Type A | Select-Object -First 1 Name, IPAddress
