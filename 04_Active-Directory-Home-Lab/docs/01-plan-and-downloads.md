# 1. Plan and downloads

## What you need

- Windows PC with 16 GB RAM and about 120 GB free disk space
- CPU virtualization turned on in BIOS/UEFI (Intel VT-x or AMD-V). Check: Task Manager > Performance > CPU > "Virtualization: Enabled"
- About 4–6 hours across a few sessions

Memory plan: DC01 gets 4 GB, CLIENT01 gets 4 GB, and Windows on your PC keeps 8 GB.

## Downloads (all free)

| What | Where | Notes |
|---|---|---|
| VirtualBox for Windows hosts | virtualbox.org > Downloads | Version 7 or newer (includes the virtual TPM Windows 11 needs) |
| Windows Server 2025 ISO | Microsoft Evaluation Center: "Windows Server 2025" > 64-bit ISO | 180-day evaluation. Must connect to the internet within the first 10 days to activate, or it shuts down on a timer |
| Windows 11 Enterprise ISO | Microsoft Evaluation Center: "Windows 11 Enterprise" > ISO – Enterprise | 90-day evaluation |

The Evaluation Center asks for a short registration form before each download. The ISOs are large (5–7 GB each).

## Names and addresses used in this lab

Write these down; every step uses them.

| Item | Value |
|---|---|
| District (fictional) | Pacific Crest Unified School District |
| Domain name | `pcusd.internal` |
| NetBIOS name | `PCUSD` |
| Lab network | `10.0.10.0/24` (VirtualBox NAT Network `PCUSD-Lab`) |
| Gateway | `10.0.10.1` (VirtualBox) |
| DC01 | `10.0.10.10` (static) |
| DHCP range | `10.0.10.100` – `10.0.10.200` |
| CLIENT01 | gets an address from DHCP |

Why `.internal`: it is reserved for private networks, so it can never clash with a real website. Avoid `.local` for Active Directory; it conflicts with tools like Bonjour.

## Passwords

Pick lab-only passwords and keep them in a password manager. You'll need:

- Local Administrator on DC01
- Directory Services Restore Mode (DSRM) password, set when you promote the DC
- Your personal admin account (`PCUSD\gavin.admin`)
- A starter password for new users (the toolkit can generate one per user instead)

Never reuse a real password in a lab, and never commit passwords to GitHub.

## Screenshots for this step

- `01-virtualization-enabled.png`: Task Manager showing virtualization enabled
