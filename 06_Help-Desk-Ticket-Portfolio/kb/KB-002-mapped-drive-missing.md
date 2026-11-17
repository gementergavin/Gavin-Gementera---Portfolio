# KB-002: Shared drive missing or "Access denied"

**Audience:** help desk staff · **Tickets:** HD-1004, HD-1016, HD-1020

Staff get **S:** (`\\DC01\Staff`) automatically through Group Policy. Students can open `\\DC01\Students` but can't save there (by design).

## Troubleshoot in this order

1. **Is it working as designed?** Students can't write to the Students share, and only IT can open the IT share. If so, explain kindly and show the right place to save. No change needed.
2. **Is the user in the right group?**
   ```powershell
   Get-ADPrincipalGroupMembership <username> | Select-Object Name
   ```
   Staff need one of `GG-Teachers`, `GG-Office` or `GG-IT`. New hires are the usual cause.
3. **Did they sign out after being added?** Group membership is read at sign-in. Have them sign out and back in.
4. **Has Group Policy run?** On their PC: `gpupdate /force`, then sign out and in. `gpresult /r` should list `PCUSD - Staff - Map S Drive`.
5. **Can the PC reach the server?** `Test-Path \\DC01\Staff` and `ping DC01`. If not, it's a network or DNS problem, not permissions.
6. **Check effective access** on the folder: Properties > Security > Advanced > **Effective Access** > pick the user.

## Map it by hand (while you fix the cause)

File Explorer > This PC > **Map network drive** > Drive `S:` > Folder `\\DC01\Staff` > Reconnect at sign-in.

## Requests for more access

Access requests need the data owner's or a supervisor's approval in the ticket. Give the smallest access that does the job (least privilege). See HD-1020 for an example of declining and offering an alternative.
