# 10. Build log

Fill this in **while** you build, not afterward. Two lines per step is enough. Your future self (and your interview answers) will thank you: the problems you hit are the best part of the project.

Tip: keep this file open in Notepad on your host PC while you work, then paste it here when you upload screenshots.

---

## Summary

| | |
|---|---|
| Started | |
| Finished | |
| Total time | |
| Host PC | Windows, 16 GB RAM, VirtualBox version: |
| DC01 OS | Windows Server 2025 Standard Evaluation, build: (run `winver`) |
| CLIENT01 OS | Windows 11 Enterprise Evaluation, build: |
| Health check result | PASS __ / WARN __ / FAIL __ |

---

## Step log

Copy this block for each step.

```
### Step _ : (name)
Date:
Time spent:
What I did:
-
What went wrong (if anything):
-
How I found the cause:
-
How I fixed it:
-
How I confirmed it worked:
-
Screenshots taken:
-
```

---

### Step 1: Plan and downloads

Date:
Time spent:
What I did:
-
What went wrong:
-
Screenshots taken:
- `01-virtualization-enabled.png`

### Step 2: Create the virtual machines

Date:
Time spent:
What I did:
-
What went wrong:
-
Screenshots taken:
- `02-nat-network.png`
- `02-vm-list.png`

### Step 3: Build the domain controller

Date:
Time spent:
What I did:
-
What went wrong:
-
Health check after this step: PASS __ / WARN __ / FAIL __
Screenshots taken:
- `03-server-manager-roles.png`
- `03-dns-manager.png`
- `03-dhcp-scope.png`

### Step 4: OUs, users and groups

Date:
Time spent:
What I did:
-
What went wrong:
-
Health check after this step: PASS __ / WARN __ / FAIL __
Screenshots taken:
- `04-aduc-ou-tree.png`
- `04-bulk-import-whatif.png`
- `04-group-membership.png`
- `04-delegation-wizard.png`

### Step 5: Join CLIENT01 to the domain

Date:
Time spent:
What I did:
-
What went wrong:
-
Screenshots taken:
- `05-ipconfig-client.png`
- `05-welcome-to-domain.png`
- `05-aduc-client-in-ou.png`
- `05-whoami.png`

### Step 6: Group Policy

Date:
Time spent:
What I did:
-
What went wrong:
-
Screenshots taken:
- `06-gpmc-links.png`
- `06-gpresult.png`
- `06-control-panel-blocked.png`
- `06-s-drive.png`
- `06-logon-banner.png`

### Step 7: File shares and permissions

Date:
Time spent:
What I did:
-
What went wrong:
-
Screenshots taken:
- `07-ntfs-permissions.png`
- `07-effective-access.png`
- `07-access-denied.png`

### Step 8: Help desk practice

| Ticket | What I did | Time | Screenshot |
|---|---|---|---|
| HD-1001 Account locked out | | | `08-unlock-account.png` |
| HD-1002 Forgotten password | | | `08-reset-password.png` |
| HD-1004 Can't open the Staff drive | | | |
| HD-1007 New hire | | | |
| HD-1008 Staff member leaves | | | `08-disabled-accounts-ou.png` |
| HD-1012 Trust relationship failed | | | |

### Final check

- [ ] `7-Test-LabHealth.ps1` shows no FAIL
- [ ] Screenshot of the HTML report saved as `09-lab-health-report.png`
- [ ] Every screenshot listed in [screenshots/README.md](../screenshots/README.md) is uploaded
- [ ] "What I learned" in the [project README](../README.md) is filled in from the problems below
- [ ] Resume bullet updated with what you actually built

---

## Problems I hit

The most useful table in the project. Each row is a ready-made interview story.

| # | Step | Symptom (what I saw) | Cause | Fix | How I confirmed |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
