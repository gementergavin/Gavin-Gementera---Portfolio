# KB-001: Password reset and account unlock

**Audience:** help desk staff · **Tickets:** HD-1001, HD-1002, HD-1019

## 1. Verify who you're talking to (always first)

Never reset a password for a caller you haven't verified. Attackers call help desks pretending to be staff.

| Requester | Verify by |
|---|---|
| Staff in person | District ID badge |
| Staff by phone | Call back the desk phone number listed in the staff directory, not the number they called from |
| Student | In person with their teacher present, or the teacher submits the ticket |

If you can't verify, don't reset. Tell the person how they can verify and note it in the ticket.

## 2. Locked out vs. forgotten password

- **Locked out:** they know the password but typed it wrong 5 times (or a device used an old one). Unlocking is enough; no reset needed. The lock also clears on its own after 15 minutes.
- **Forgot it:** reset to a temporary password and make them change it at next sign-in.

## 3. Unlock

**ADUC:** find the user > Properties > **Account** tab > check **Unlock account** > OK.

**PowerShell:**
```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName
Unlock-ADAccount -Identity <username>
```

## 4. Reset

**ADUC:** right-click the user > **Reset Password** > enter a temporary password > check **User must change password at next logon** and **Unlock the user's account**.

**PowerShell (toolkit):**
```powershell
Reset-HelpDeskPassword -Identity <username> -TicketNumber HD-####
```

Give the temporary password only to the verified person: in person, or read it on the callback. Never email it.

## 5. Locked out again and again

Something is still using the old password: a phone's email app, a mapped drive with saved credentials, or a second PC still signed in.

1. On the DC, find where the lockout came from: Event Viewer > Windows Logs > **Security** > filter for **Event ID 4740**. "Caller Computer Name" shows the device.
   ```powershell
   Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740 } -MaxEvents 20 |
       Select-Object TimeCreated, @{ n = 'User'; e = { $_.Properties[0].Value } }, @{ n = 'From'; e = { $_.Properties[1].Value } }
   ```
2. Update or remove the old password on that device.

## 6. Close the ticket

Note how you verified the person, whether it was an unlock or a reset, and the cause if known.
