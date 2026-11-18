# 3. Build the domain controller (AD DS, DNS, DHCP)

> New to this? Read [0. How it works](00-how-it-works.md) sections 2–4 first: what a domain controller is, why DNS matters, and how DHCP works.

Do these on **DC01**. Copy the [scripts](../scripts) folder into the VM first: turn on **Devices > Shared Clipboard > Bidirectional** and paste, or use **Devices > Shared Folders**.

Before running any script, open PowerShell **as Administrator** and allow local scripts for this session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## 3.1 Static IP and name

**Script:** `.\1-Set-DC01Network.ps1` (restarts the VM)

**GUI way:** Settings > Network & Internet > Ethernet > IP assignment > Edit > Manual: IP `10.0.10.10`, prefix `24`, gateway `10.0.10.1`, DNS `1.1.1.1`. Then Settings > System > About > Rename this PC > `DC01`.

**Why:** clients find the domain controller through DNS at a fixed address. If DC01's address changed, logons and domain joins would break.

**Check:** `ipconfig /all` shows 10.0.10.10, and `ping www.microsoft.com` gets replies.

**Activate Windows now** (Settings > System > Activation). The evaluation shuts down on a timer if it isn't activated within 10 days.

## 3.2 Install AD DS and create the forest

**Script:** `.\2-Install-ADForest.ps1` (asks for the DSRM password, then restarts)

**GUI way:**
1. Server Manager > Manage > Add Roles and Features > Role-based > DC01 > check **Active Directory Domain Services** > Add Features > Install.
2. Click the flag at the top of Server Manager > **Promote this server to a domain controller**.
3. **Add a new forest**, root domain name `pcusd.internal`.
4. Leave the functional levels at the newest, keep **DNS server** checked, enter the DSRM password.
5. NetBIOS name `PCUSD`. Accept the default paths. Install.

**What this did:** created the `pcusd.internal` domain, made DC01 its first domain controller, and installed DNS with a zone for the domain. Log back in as **PCUSD\Administrator** (same password as the local Administrator).

**Check:**

```powershell
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, PDCEmulator
Get-DnsServerZone | Select-Object ZoneName, ZoneType
```

**What you should see:**

```
DNSRoot        NetBIOSName PDCEmulator
-------        ----------- -----------
pcusd.internal PCUSD       DC01.pcusd.internal

ZoneName              ZoneType
--------              --------
_msdcs.pcusd.internal Primary
0.in-addr.arpa        Primary
127.in-addr.arpa      Primary
255.in-addr.arpa      Primary
pcusd.internal        Primary
TrustAnchors          Primary
```

The `0`, `127` and `255` zones are created automatically; leave them. The important ones are `pcusd.internal` and `_msdcs.pcusd.internal`, which hold the records clients use to find the DC. Also run `ipconfig /all`: promotion changed DC01's DNS server to `127.0.0.1` (itself). That's correct.

## 3.3 DNS forwarders and DHCP

**Script:** `.\3-Set-DnsAndDhcp.ps1`

**GUI way:**
- DNS Manager > right-click DC01 > Properties > **Forwarders** > add `1.1.1.1` and `8.8.8.8`.
- DNS Manager > Reverse Lookup Zones > New Zone > Primary, AD-integrated > Network ID `10.0.10`.
- Server Manager > Add Roles and Features > **DHCP Server** > Install > click the flag > **Complete DHCP configuration** > Commit.
- DHCP console > IPv4 > New Scope: name `PCUSD-Lab`, range `10.0.10.100`–`10.0.10.200`, mask `255.255.255.0`, router `10.0.10.1`, DNS server `10.0.10.10`, domain `pcusd.internal` > Activate.

**Why forwarders:** DC01 answers DNS for `pcusd.internal` and passes everything else (like google.com) to public DNS. Clients use only DC01 for DNS; if a domain PC used 8.8.8.8 instead, it couldn't find the domain.

**Check:**

```powershell
Get-DhcpServerv4Scope
Get-DhcpServerv4OptionValue -ScopeId 10.0.10.0
Resolve-DnsName www.microsoft.com -Type A
```

**What you should see:**

```
ScopeId    SubnetMask     Name       State   StartRange   EndRange     LeaseDuration
-------    ----------     ----       -----   ----------   --------     -------------
10.0.10.0  255.255.255.0  PCUSD-Lab  Active  10.0.10.100  10.0.10.200  1.00:00:00

OptionId Name            Type        Value                VendorClass UserClass
-------- ----            ----        -----                ----------- ---------
3        Router          IPv4Address {10.0.10.1}
6        DNS Servers     IPv4Address {10.0.10.10}
15       DNS Domain Name String      {pcusd.internal}
```

…followed by one or more IP addresses for `www.microsoft.com` (they change, so yours will differ). Option 6 must be `10.0.10.10`; that's the line that makes the domain join work later.

## 3.4 Run the health check

```powershell
.\7-Test-LabHealth.ps1
```

After this step the **Server, Services, Domain, DNS and DHCP** sections should all be PASS (two WARNs are normal here: activation, until you activate, and "Leases handed out", until CLIENT01 is on the network). Everything from **Structure** down will FAIL with the step that fixes it; that's expected. Write your PASS/FAIL count in the [build log](10-build-log.md).

## Screenshots for this step

- `03-server-manager-roles.png`: Server Manager dashboard showing AD DS, DNS, DHCP
- `03-dns-manager.png`: DNS Manager with the `pcusd.internal` and reverse zones
- `03-dhcp-scope.png`: DHCP console showing the active `PCUSD-Lab` scope

## Troubleshooting

| Problem | Likely cause and fix |
|---|---|
| Promotion fails with a static IP warning | Re-run step 3.1; the adapter still has DHCP turned on |
| No internet after promotion | DNS forwarders missing; re-run step 3.3 |
| DHCP console shows a red arrow on the server | Not authorized: DHCP console > right-click the server > Authorize |
