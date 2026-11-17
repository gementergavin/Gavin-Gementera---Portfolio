# 8. Help desk practice

Common help desk requests, done both ways. Each matches a ticket in the [help desk ticket portfolio](../../06_Help-Desk-Ticket-Portfolio). Work them in the lab, screenshot the result, and write what you did in the ticket.

Run the PowerShell on DC01 (or on CLIENT01 with RSAT installed) as `PCUSD\gavin.admin`.

## Account locked out (ticket HD-1001)

1. Lock a student account on purpose: type the wrong password 5 times on CLIENT01.
2. **Verify the person** before unlocking. In a real district, use the verification steps in [KB-001](../../06_Help-Desk-Ticket-Portfolio/kb/KB-001-password-reset-and-unlock.md).
3. **GUI:** ADUC > find the user > Properties > **Account** tab > check **Unlock account**.
4. **PowerShell:**

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName
Unlock-ADAccount -Identity jayden.nguyen
```

## Forgotten password (HD-1002)

**GUI:** ADUC > right-click the user > **Reset Password** > check **User must change password at next logon**.

**PowerShell (toolkit):**

```powershell
Reset-HelpDeskPassword -Identity jayden.nguyen -TicketNumber HD-1002
```

This unlocks the account, sets a random temporary password, forces a change at next sign-in, and logs the ticket number.

## "I can't open the Staff drive" (HD-1004)

Troubleshoot in order:

1. Is the user in the right group? `Get-ADPrincipalGroupMembership sofia.ramirez | Select-Object Name`
2. Did they sign out and back in after being added? Group membership is read at sign-in. Have them sign out, or run `klist purge` and reconnect.
3. Does the share path work? `Test-Path \\DC01\Staff`
4. Effective Access on the folder (step 7) shows exactly which permission is missing.

Practice it: remove a teacher from `GG-Teachers`, confirm the S: drive breaks, then fix it.

## New hire (HD-1007)

Add one row to a CSV and run `New-BulkADUser`. Check the account, group, OU and "must change password" setting. Then sign in on CLIENT01 as the new user.

## Staff member leaves (HD-1008)

The account is disabled, not deleted, so files and history stay available.

**GUI:** right-click the user > **Disable Account**, remove group memberships, move to **Disabled Accounts**, and add the date and ticket number to the Description.

**PowerShell:**

```powershell
$user = 'leaving.user'
Disable-ADAccount -Identity $user
Get-ADPrincipalGroupMembership $user | Where-Object Name -ne 'Domain Users' |
    ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $user -Confirm:$false }
Set-ADUser $user -Description "Disabled $(Get-Date -Format yyyy-MM-dd) - HD-1008"
Get-ADUser $user | Move-ADObject -TargetPath 'OU=Disabled Accounts,OU=PCUSD,DC=pcusd,DC=internal'
```

## "My computer says the trust relationship failed" (HD-1012)

Reproduce it: take a VirtualBox snapshot of CLIENT01, wait for (or force) a machine password change, then restore the snapshot. Fix it:

```powershell
Test-ComputerSecureChannel -Repair -Credential PCUSD\gavin.admin
```

## Screenshots for this step

- `08-unlock-account.png`
- `08-reset-password.png`
- `08-disabled-accounts-ou.png`
