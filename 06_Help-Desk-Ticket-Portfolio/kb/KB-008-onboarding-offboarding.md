# KB-008: New staff and leaving staff checklists

**Audience:** help desk staff · **Tickets:** HD-1007, HD-1008

## New staff (onboarding)

Start only from a request from HR or the principal (never from the new hire alone).

- [ ] Account created in the right OU with the right role group (`New-BulkADUser`, or ADUC)
- [ ] "Must change password at next logon" is set
- [ ] Email and Microsoft 365 license assigned
- [ ] Added to the school's staff distribution list
- [ ] Device assigned and recorded in the device tracker
- [ ] Temporary password delivered to the principal or HR in a sealed envelope, never by email
- [ ] First-day check: the new hire signs in, sets up MFA (KB-007), and sees the S: drive

## Leaving staff (offboarding)

Do it at the time HR gives (usually 5 PM on the last day), not before.

- [ ] Account **disabled**, not deleted
- [ ] Removed from all groups except Domain Users
- [ ] Moved to `PCUSD > Disabled Accounts`
- [ ] Description set to `Disabled YYYY-MM-DD - HD-####`
- [ ] Mailbox and files handed to the manager as HR asks
- [ ] Devices collected and checked in to the device tracker
- [ ] After 90 days (per policy), the account can be deleted with HR's approval

PowerShell for the disable steps is in the [AD lab help desk practice guide](../../04_Active-Directory-Home-Lab/docs/08-help-desk-practice.md).
