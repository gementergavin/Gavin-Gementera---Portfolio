# Build guide (Cisco Packet Tracer)

About 3–4 hours. Save often (**File > Save As** `pcusd-school-network.pkt`).

## 0. Get Packet Tracer

Packet Tracer is free from Cisco Networking Academy (netacad.com). Create a free account, enroll in the free **Getting Started with Cisco Packet Tracer** course or use the resources page, and download the Windows version. You sign in with the same account when Packet Tracer opens.

## 1. Place the devices

| Name | Device in Packet Tracer | Where to find it |
|---|---|---|
| ISP | ISR4331 router | Network Devices > Routers |
| R1 | ISR4331 router | Network Devices > Routers |
| SW-CORE, SW-ACCESS-1, SW-ACCESS-2 | 2960-24TT switch | Network Devices > Switches |
| AP-GUEST | AccessPoint-PT | Network Devices > Wireless Devices |
| INTERNET-SRV, SRV-PCUSD | Server-PT | End Devices |
| IT-PC, STAFF-PC1, STAFF-PC2, TEACHER-PC, STUDENT-PC1, STUDENT-PC2 | PC-PT | End Devices |
| GUEST-LAPTOP | Laptop-PT | End Devices |

Rename each device: click it > **Config** tab > Display Name.

## 2. Cable it

Like devices (router to router, switch to switch, router to PC) use a **cross-over** cable; unlike devices (switch to router, switch to PC) use **straight-through**. The lightning-bolt "Automatic Connection Type" also picks correctly, but choose the ports yourself so they match the configs.

| From | Port | To | Port | Cable |
|---|---|---|---|---|
| ISP | G0/0/0 | R1 | G0/0/0 | Cross-over |
| ISP | G0/0/1 | INTERNET-SRV | Fa0 | Cross-over |
| R1 | G0/0/1 | SW-CORE | Gi0/1 | Straight-through |
| SW-CORE | Fa0/23 | SW-ACCESS-1 | Fa0/24 | Cross-over |
| SW-CORE | Fa0/24 | SW-ACCESS-2 | Fa0/24 | Cross-over |
| SW-CORE | Fa0/1 | SRV-PCUSD | Fa0 | Straight-through |
| SW-CORE | Fa0/2 | IT-PC | Fa0 | Straight-through |
| SW-ACCESS-1 | Fa0/1, Fa0/2 | STAFF-PC1, STAFF-PC2 | Fa0 | Straight-through |
| SW-ACCESS-1 | Fa0/21 | AP-GUEST | Port 0 | Straight-through |
| SW-ACCESS-2 | Fa0/1, Fa0/2 | STUDENT-PC1, STUDENT-PC2 | Fa0 | Straight-through |
| SW-ACCESS-2 | Fa0/17 | TEACHER-PC | Fa0 | Straight-through |

Link lights turn green after the switches finish spanning tree (up to 30 seconds; click the fast-forward button to speed it up).

## 3. Configure the network devices

For each device: click it > **CLI** tab > press Enter > paste the matching file from [configs](../configs) (right-click > Paste). Order: **ISP, R1, SW-CORE, SW-ACCESS-1, SW-ACCESS-2**.

Then turn on SSH on R1 and each switch (this step asks a question, so type it rather than paste):

```
enable
configure terminal
crypto key generate rsa
   (answer 1024 when asked for the modulus size)
ip ssh version 2
end
write memory
```

Note: the configs set `login local` on the console, so the CLI now asks for a username: `netadmin` and the password you chose.

## 4. Configure the servers

**INTERNET-SRV** (stands in for a website on the internet):
- Desktop > IP Configuration: Static, IP `198.51.100.10`, mask `255.255.255.0`, gateway `198.51.100.1`, DNS `198.51.100.10`.
- Services > **DNS**: On. Add an A record `www.example.test` > `198.51.100.10`.
- Services > **HTTP**: On. Edit `index.html` to say "Public website (internet)".

**SRV-PCUSD** (district server):
- IP `10.10.40.10`, mask `255.255.255.0`, gateway `10.10.40.1`, DNS `10.10.40.10`.
- Services > **DNS**: On. Records: `portal.pcusd.internal` > `10.10.40.10`, and `www.example.test` > `198.51.100.10` (so district devices can reach the "internet" site by name).
- Services > **HTTP**: On. Edit `index.html` to say "PCUSD Staff Portal".

## 5. Configure the clients

- **IT-PC, STAFF-PC1, STAFF-PC2, TEACHER-PC, STUDENT-PC1, STUDENT-PC2:** Desktop > IP Configuration > **DHCP**. Each should get an address from its VLAN within a few seconds.
- **AP-GUEST:** Config > Port 1: SSID `PCUSD-Guest`, Authentication **WPA2-PSK**, passphrase of your choice (8+ characters).
- **GUEST-LAPTOP:** Physical tab > power off > drag out the wired card > drag in **WPC300N** (wireless) > power on. Desktop > PC Wireless (or Config > Wireless0): SSID `PCUSD-Guest`, WPA2-PSK, same passphrase. IP Configuration > DHCP. It should get a `10.10.30.x` address.

## 6. Test

Work through [test-plan.md](test-plan.md) and record the actual results. Use **Simulation mode** to watch an ACL drop a packet.

## 7. Save and screenshot

Save `pcusd-school-network.pkt` into this folder and commit it. Screenshots for [screenshots](../screenshots):

- `topology.png`: the whole logical topology
- `show-vlan-brief.png`: `show vlan brief` on SW-ACCESS-2
- `show-ip-dhcp-binding.png`: `show ip dhcp binding` on R1
- `acl-denied.png`: a student PC's ping to a staff PC failing
- `show-access-lists.png`: `show access-lists` on R1 with match counts
- `show-ip-nat-translations.png`: after a student browses to `www.example.test`
- `port-security.png`: `show port-security interface fa0/1` on SW-ACCESS-2
