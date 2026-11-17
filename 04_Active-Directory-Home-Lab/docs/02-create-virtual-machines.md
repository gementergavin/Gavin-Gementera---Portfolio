# 2. Create the virtual machines

## 2.1 Create the NAT Network

A NAT Network lets the VMs talk to each other and reach the internet, while keeping them off your home network.

1. Open VirtualBox > **File > Tools > Network Manager** > **NAT Networks** tab > **Create**.
2. Name: `PCUSD-Lab`. IPv4 Prefix: `10.0.10.0/24`.
3. **Uncheck "Enable DHCP".** DC01 will run DHCP instead. Two DHCP servers on one network cause random address problems.
4. Apply.

## 2.2 DC01 (Windows Server 2025)

1. **Machine > New**. Name: `DC01`. ISO: the Windows Server 2025 ISO. Type: Microsoft Windows, Version: Windows 2025 (64-bit) (or Windows 2022 if 2025 isn't listed).
2. Check **Skip Unattended Installation**, so you do the install yourself and see each screen.
3. Memory: **4096 MB**. Processors: **2**.
4. Disk: **60 GB**, dynamically allocated.
5. Before starting: **Settings > Network > Adapter 1** > Attached to: **NAT Network** > Name: `PCUSD-Lab`.
6. Start the VM and install:
   - Edition: **Windows Server 2025 Standard Evaluation (Desktop Experience)**. The non-"Desktop Experience" option has no GUI.
   - Custom install > the 60 GB disk.
   - Set the local Administrator password.
7. After login: **Devices > Insert Guest Additions CD image**, run `VBoxWindowsAdditions.exe` from the CD drive, reboot. This gives you a resizable screen and shared clipboard.

## 2.3 CLIENT01 (Windows 11 Enterprise)

1. **Machine > New**. Name: `CLIENT01`. ISO: the Windows 11 Enterprise ISO. Version: Windows 11 (64-bit). Check **Skip Unattended Installation**.
2. Memory: **4096 MB**. Processors: **2**. Disk: **64 GB**.
3. Confirm in **Settings > System**: **EFI** enabled, **TPM v2.0**, **Secure Boot** on. VirtualBox 7 sets these for the Windows 11 type.
4. **Settings > Network > Adapter 1** > NAT Network `PCUSD-Lab`.
5. Install Windows 11 Enterprise. **Don't start it yet**: CLIENT01 needs DC01's DHCP and DNS (step 3) before it can get on the network. If you already started it, that's fine. Choose "Domain join instead" / sign-in options > local account if the setup asks for a Microsoft account; you'll join the domain in step 5.

## Troubleshooting

| Problem | Fix |
|---|---|
| "VT-x is not available" or the VM is very slow (green turtle icon in the status bar) | Turn on virtualization in BIOS. If Windows Hyper-V/Memory Integrity is on, VirtualBox runs in a slower mode; it still works for this lab. |
| Windows 11 says "This PC can't run Windows 11" | Check EFI, Secure Boot and TPM 2.0 in Settings > System, and that RAM is at least 4096 MB |
| No network after install | Adapter 1 must be "NAT Network" > `PCUSD-Lab`, not plain "NAT" |

## Screenshots for this step

- `02-nat-network.png`: Network Manager showing `PCUSD-Lab`, 10.0.10.0/24, DHCP off
- `02-vm-list.png`: VirtualBox with DC01 and CLIENT01
