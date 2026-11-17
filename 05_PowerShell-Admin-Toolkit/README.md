# PowerShell Admin Toolkit

A PowerShell module of help desk and sysadmin tasks I automated for my [Active Directory home lab](../04_Active-Directory-Home-Lab) (Pacific Crest Unified School District, fictional). It creates accounts in bulk from a spreadsheet, handles password resets, reports expiring passwords and inactive accounts, and checks a PC's health.

Works in Windows PowerShell 5.1 (built into Windows Server) and PowerShell 7.

## Functions

| Function | What it does | Needs AD? |
|---|---|---|
| `New-BulkADUser` | Creates users from a CSV: checks each row, builds a unique `first.last` username, picks the OU and role group by role, sets a random temporary password, and forces a change at first sign-in. Supports `-WhatIf` | Yes |
| `Reset-HelpDeskPassword` | Unlocks the account, sets a temporary password, forces a change at next sign-in, logs the ticket number | Yes |
| `Get-PasswordExpiryReport` | Users whose passwords expire within N days | Yes |
| `Get-InactiveUserReport` | Accounts with no sign-in for N days (skips new hires) | Yes |
| `Disable-InactiveUser` | Disables those accounts and moves them to `Disabled Accounts`. Supports `-WhatIf` | Yes |
| `Get-SystemHealthReport` | HTML health report for this PC: uptime, memory, disks, pending restart, stopped services, recent errors | **No: try it on your own PC** |
| `ConvertTo-PcusdUsername`, `New-PcusdTempPassword`, `Test-PcusdUserRow`, `Get-PcusdRoleSettings`, `Get-PasswordExpiryStatus`, `Get-DiskStatus` | Building blocks used by the functions above | No |

## Quick start

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module .\AdminTools\AdminTools.psd1
Get-Command -Module AdminTools
Get-Help New-BulkADUser -Full
```

### On any Windows PC

```powershell
.\scripts\Invoke-HealthReport.ps1       # saves an HTML report to the Desktop and opens it
```

### On DC01 (the lab domain controller)

```powershell
# Preview: shows what would be created, changes nothing
New-BulkADUser -CsvPath .\data\new-users.csv -WhatIf

# Create the 20 sample users
New-BulkADUser -CsvPath .\data\new-users.csv

# See how bad rows are handled: 2 created, 3 skipped with reasons
New-BulkADUser -CsvPath .\data\new-users-with-errors.csv -WhatIf

Reset-HelpDeskPassword -Identity jayden.nguyen -TicketNumber HD-1002
Get-PasswordExpiryReport -Days 14
Disable-InactiveUser -Days 120 -WhatIf
.\scripts\Invoke-WeeklyAccountReports.ps1
```

## CSV format

| Column | Required | Example |
|---|---|---|
| FirstName | Yes | `Maria` |
| LastName | Yes | `Lopez` |
| Role | Yes: `Teacher`, `Office`, `IT` or `Student` | `Teacher` |
| School | No | `Crestview Elementary` |
| Title | No | `3rd Grade Teacher` |
| IdNumber | No, 4–10 digits | `100231` |

The sample file includes names that test the username rules: an accented name (José Núñez → `jose.nunez`), an apostrophe (O'Brien → `liam.obrien`), a hyphen (Smith-Jones → `ethan.smithjones`), and two people named Maria Lopez (`maria.lopez` and `maria.lopez2`).

## Design choices

- **`-WhatIf` on everything that changes AD**, so a CSV can be checked before anything is created.
- **Validation before changes:** a bad row is skipped with a reason; the rest still run.
- **Temporary passwords never go to the screen output or logs.** Bulk creation writes them to one CSV to hand out; the reset function shows one on screen to read to a verified user. Both force a change at first sign-in.
- **No hard-coded domain:** OUs are built from `Get-ADDomain`, so the module works in any domain with the same OU layout.
- **Inactive-account safety:** accounts created recently are never flagged, and `lastLogonTimestamp` only updates every 9–14 days, so the minimum is 30 days.

## Tests

The tests use [Pester 5](https://pester.dev). Windows ships with an old Pester 3, so install the new one once:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
Invoke-Pester -Path .\tests -Output Detailed
```

The Active Directory commands are mocked, so the tests run on a PC without AD. They cover username rules, password rules, CSV validation, role-to-OU mapping, expiry math, disk thresholds, and `New-BulkADUser` with and without `-WhatIf`.

## Interview talking points

- **Why automate account creation?** At the start of a school year a district creates hundreds of student accounts. Doing it by hand is slow and inconsistent; a script applies the same naming, OU and group rules every time.
- **Why `-WhatIf`?** I can show a supervisor exactly what will change before anything changes.
- **sAMAccountName is limited to 20 characters,** so long names are shortened and duplicates get a number.
- **Least privilege:** the reset function works for anyone delegated "reset password" on an OU; it doesn't need Domain Admin.
