# 3. Build the domain controller (AD DS, DNS, DHCP)

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

## 3.3 DNS forwarders and DHCP

**Script:** `.\3-Set-DnsAndDhcp.ps1`

**GUI way:**
- DNS Manager > right-click DC01 > Properties > **Forwarders** > add `1.1.1.1` and `8.8.8.8`.
- DNS Manager > Reverse Lookup Zones > New Zone > Primary, AD-integrated > Network ID `10.0.10`.
- Server Manager > Add Roles and Features > **DHCP Server** > Install > click the flag > **Complete DHCP configuration** > Commit.
- DHCP console > IPv4 > New Scope: name `PCUSD-Lab`, range `10.0.10.100`–`10.0.10.200`, mask `255.255.255.0`, router `10.0.10.1`, DNS server `10.0.10.10`, domain `pcusd.internal` > Activate.

**Why forwarders:** DC01 answers DNS for `pcusd.internal` and passes everything else (like google.com) to public DNS. Clients use only DC01 for DNS; if a domain PC used 8.8.8.8 instead, it couldn't find the domain.

**Check:** `Get-DhcpServerv4Scope` shows the scope as Active, and `Resolve-DnsName www.microsoft.com` returns an address.

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
