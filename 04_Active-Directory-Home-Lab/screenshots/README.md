# Screenshots

Every screenshot in this folder comes from my own lab. Each step in the build guide lists the screenshots to take; the full list is below.

## How to take them

**Option 1: VirtualBox (cleanest, captures only the VM screen)**
In the VM window: **View > Take Screenshot** (or press **Right Ctrl + E**). VirtualBox asks where to save it as a PNG. This captures the VM's screen at full resolution without your host taskbar.

**Option 2: Snipping Tool (when you want just part of the screen)**
Press **Win + Shift + S**, choose **Rectangle**, drag around the window or dialog. It copies to the clipboard and opens a notification; click it to save as PNG.

**Make them readable**
- Before capturing, set the VM display to **1920 × 1080** or **1600 × 900** (VirtualBox: **View > Virtual Screen 1 > Resize**). Tiny screenshots are hard to read on GitHub.
- Maximize the console you're capturing (ADUC, GPMC, DNS Manager) and expand the tree so the important part is visible.
- For PowerShell, use a large window with a dark or light theme, and clear the screen first (`cls`) so only the relevant output shows.
- Crop to what matters. A whole desktop with a small dialog in the middle is harder to read than the dialog alone.

**Keep them safe**
- Never show a real password. The temporary password CSV from step 4 must not appear in any screenshot.
- Crop out anything from your host PC: browser tabs, notifications, your real name or email.
- Lab names like `maria.lopez` are fictional, so they're fine to show.

## Naming

Use the exact file names below, lowercase with dashes. The step docs and the README link to these names, so the images appear in the right place automatically once uploaded.

## Uploading to GitHub

1. Go to this folder on GitHub: `04_Active-Directory-Home-Lab/screenshots`.
2. **Add file > Upload files**, drag the PNGs in, and commit with a message like `Add step 3 screenshots`.
3. To show one in a doc, add a line like this:

```markdown
![DHCP scope active](../screenshots/03-dhcp-scope.png)
```

(From the project README, the path is `screenshots/03-dhcp-scope.png` instead.)

## Checklist

| Step | File | What it shows | Done |
|---|---|---|---|
| 1 | `01-virtualization-enabled.png` | Task Manager > Performance > CPU showing **Virtualization: Enabled** | ☐ |
| 2 | `02-nat-network.png` | Network Manager: `PCUSD-Lab`, 10.0.10.0/24, DHCP **unchecked** | ☐ |
| 2 | `02-vm-list.png` | VirtualBox with DC01 and CLIENT01 and their RAM/network settings | ☐ |
| 3 | `03-server-manager-roles.png` | Server Manager dashboard tiles for AD DS, DNS, DHCP | ☐ |
| 3 | `03-dns-manager.png` | DNS Manager with `pcusd.internal`, `_msdcs` and the reverse zone expanded | ☐ |
| 3 | `03-dhcp-scope.png` | DHCP console: scope `PCUSD-Lab` active, with Scope Options showing 003, 006, 015 | ☐ |
| 4 | `04-aduc-ou-tree.png` | ADUC: full OU tree expanded, Teachers OU selected showing users | ☐ |
| 4 | `04-bulk-import-whatif.png` | PowerShell `-WhatIf` preview of the CSV import | ☐ |
| 4 | `04-group-membership.png` | A teacher's **Member Of** tab showing `GG-Teachers` | ☐ |
| 4 | `04-delegation-wizard.png` | Delegate Control wizard task page with reset password checked | ☐ |
| 5 | `05-ipconfig-client.png` | `ipconfig /all` on CLIENT01: 10.0.10.1xx, DNS 10.0.10.10, suffix pcusd.internal | ☐ |
| 5 | `05-welcome-to-domain.png` | "Welcome to the pcusd.internal domain" | ☐ |
| 5 | `05-aduc-client-in-ou.png` | CLIENT01 in `Staff Computers` | ☐ |
| 5 | `05-whoami.png` | `whoami` and `whoami /groups \| findstr GG-` as a teacher | ☐ |
| 6 | `06-gpmc-links.png` | GPMC tree with each GPO linked under its OU | ☐ |
| 6 | `06-gpresult.png` | `gpresult /r` on CLIENT01 as a student (applied GPOs listed) | ☐ |
| 6 | `06-control-panel-blocked.png` | "This operation has been cancelled due to restrictions" as a student | ☐ |
| 6 | `06-s-drive.png` | File Explorer showing `Staff (\\DC01) (S:)` as a teacher | ☐ |
| 6 | `06-logon-banner.png` | The acceptable use banner before sign-in | ☐ |
| 7 | `07-ntfs-permissions.png` | Advanced Security Settings for `C:\Shares\Students` (inheritance disabled, DL groups only) | ☐ |
| 7 | `07-effective-access.png` | Effective Access for a student on the Students share (Read, not Write) | ☐ |
| 7 | `07-access-denied.png` | A student getting "access denied" saving to the Students share | ☐ |
| 8 | `08-unlock-account.png` | Account tab with "Unlock account" checked, or `Unlock-ADAccount` output | ☐ |
| 8 | `08-reset-password.png` | Reset Password dialog with "User must change password" checked (no password visible) | ☐ |
| 8 | `08-disabled-accounts-ou.png` | A disabled leaver in `Disabled Accounts` | ☐ |
| 9 | `09-lab-health-report.png` | HTML report from `7-Test-LabHealth.ps1` with no FAIL | ☐ |

Tick the box (change ☐ to ✅) as each one is uploaded.
