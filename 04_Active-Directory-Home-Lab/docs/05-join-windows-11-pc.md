# 5. Join a Windows 11 PC to the domain

## 5.1 Check the network first

Start **CLIENT01** and sign in with the local account you made during setup. Open Command Prompt:

```
ipconfig /all
```

**What you should see** (the part that matters; your address may be any from .100 to .200):

```
Ethernet adapter Ethernet:

   Connection-specific DNS Suffix  . : pcusd.internal
   ...
   DHCP Enabled. . . . . . . . . . . : Yes
   IPv4 Address. . . . . . . . . . . : 10.0.10.100(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 10.0.10.1
   DHCP Server . . . . . . . . . . . : 10.0.10.10
   DNS Servers . . . . . . . . . . . : 10.0.10.10
```

You should see an address from `10.0.10.100`–`10.0.10.200`, **DNS Servers: 10.0.10.10**, and **Connection-specific DNS Suffix: pcusd.internal**. That proves DHCP on DC01 works.

```
nslookup pcusd.internal
ping dc01.pcusd.internal
```

Both should answer from 10.0.10.10:

```
Server:  dc01.pcusd.internal
Address:  10.0.10.10

Name:    pcusd.internal
Address:  10.0.10.10
```

If `Server:` says `UnKnown`, DC01 doesn't have a reverse (PTR) record yet. It doesn't stop the join; run `ipconfig /registerdns` on DC01 to fix it.

One more check, the same lookup Windows does when joining:

```
nltest /dsgetdc:pcusd.internal
```

It should list `DC: \\DC01.pcusd.internal` and `Address: \\10.0.10.10`, then `The command completed successfully`.

**If DNS points anywhere other than DC01, the join will fail.** This is the most common domain-join problem.

## 5.2 Rename and join

**GUI way:**
1. Settings > System > About > **Rename this PC** > `CLIENT01` > restart.
2. Settings > System > About > **Domain or workgroup** (or run `sysdm.cpl`) > Change > **Domain**: `pcusd.internal`.
3. When asked for credentials, use `PCUSD\gavin.admin`.
4. "Welcome to the pcusd.internal domain" > restart.

**PowerShell way** (as Administrator on CLIENT01):

```powershell
Rename-Computer -NewName CLIENT01 -Restart
# after the restart:
Add-Computer -DomainName pcusd.internal -Credential PCUSD\gavin.admin -Restart
```

## 5.3 Put the computer in the right OU

New computers land in the default `Computers` container, where none of the district GPOs apply. On DC01:

```powershell
Get-ADComputer CLIENT01 |
    Move-ADObject -TargetPath 'OU=Staff Computers,OU=Computers,OU=PCUSD,DC=pcusd,DC=internal'
```

or in ADUC, drag CLIENT01 from **Computers** into **PCUSD > Computers > Staff Computers**. Later in step 6 you'll move it to **Student Computers** to see the student policies apply.

## 5.4 Sign in as a domain user

On CLIENT01's sign-in screen choose **Other user** and sign in as a teacher from the CSV, for example `PCUSD\maria.lopez` with her temporary password. Windows makes her choose a new one.

```
whoami
whoami /groups | findstr GG-
```

**What you should see:** `pcusd\maria.lopez`, then a line starting with `PCUSD\GG-Teachers`. If you run `whoami /groups` without the filter, you'll also see the `DL-` groups GG-Teachers is nested in. That's AGDLP showing up in her sign-in token ([why](00-how-it-works.md#5-joining-the-domain-and-signing-in)).

On DC01, run `.\7-Test-LabHealth.ps1`: the **Client** section should now pass.

## Screenshots for this step

- `05-ipconfig-client.png`: `ipconfig /all` on CLIENT01 showing DHCP address and DNS 10.0.10.10
- `05-welcome-to-domain.png`: the "Welcome to the pcusd.internal domain" message
- `05-aduc-client-in-ou.png`: CLIENT01 inside `Staff Computers` in ADUC
- `05-whoami.png`: a domain user's `whoami` output

## Troubleshooting

| Error | Cause and fix |
|---|---|
| "An Active Directory Domain Controller for the domain could not be contacted" | CLIENT01's DNS isn't 10.0.10.10. Check `ipconfig /all`; check the DHCP scope options on DC01 |
| CLIENT01 has a 169.254.x.x address | No DHCP. Check the DHCP scope is active and authorized, and the VirtualBox NAT Network has its own DHCP turned off |
| "The trust relationship between this workstation and the primary domain failed" | Happens after restoring a VM snapshot. Sign in locally, leave the domain, rejoin (or `Test-ComputerSecureChannel -Repair -Credential PCUSD\gavin.admin`) |
