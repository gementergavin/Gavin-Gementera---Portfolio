# 9. Explaining the lab in an interview

Interviewers for help desk and junior admin roles almost always ask about home labs. They're checking two things: did you really build it, and do you understand what you built. This page helps with both.

**Only claim what you did.** After the build, edit the answers below so they match your lab and your problems. An honest "I hit this error and here's how I fixed it" beats a perfect textbook answer.

---

## The 60-second version

Practice saying this out loud until it sounds like you, not like a script.

> "I built a small school district network in VirtualBox to practice the work a help desk and junior sysadmin do. There's a Windows Server 2025 domain controller running Active Directory, DNS and DHCP, and a Windows 11 PC joined to the domain.
>
> I set up OUs for staff, students and computers, created 20 users from a CSV with a PowerShell script I wrote, and used role groups nested into permission groups, the AGDLP model, for the file shares. I wrote Group Policies for the password policy, a mapped drive for staff, and restrictions on student accounts and computers.
>
> Then I used it to practice tickets: unlocking accounts, password resets, fixing 'I can't open the shared drive', and onboarding and offboarding. The hardest part was [your real problem]. I fixed it by [what you did]."

---

## "Walk me through it" follow-ups

Short answers first. If they want more, the [deep dive](00-how-it-works.md) has the detail.

**Why does a domain PC have to use the DC for DNS?**
Clients find the domain controller through SRV records in DNS. Public DNS doesn't have those records, so a PC pointed at 8.8.8.8 can't find the domain. The DC forwards internet lookups to public DNS, so the PC still gets internet.

**What's the difference between an OU and a group?**
OUs organize objects so Group Policy and delegation can target them. Groups grant access to things. A user is in one OU but can be in many groups.

**Explain AGDLP.**
Accounts go into global role groups like GG-Teachers. Those go into domain local permission groups like DL-Staff-Share-Modify, and only the DL groups get permissions on the folder. Adding a new teacher is one membership change, and the folder's permission list never has individual names on it.

**Share permissions vs NTFS permissions?**
Share permissions only apply over the network; NTFS applies always. Over the network Windows uses whichever is more restrictive. I kept share permissions broad and did the real control in NTFS, so there's one place to troubleshoot.

**A GPO isn't applying. What do you check?**
Is the user or computer actually in the OU it's linked to? Is it a user setting linked to a user OU, or a computer setting linked to a computer OU? Then `gpresult /r` on the PC to see what applied, and `gpresult /h` for the denied list and the reason. `gpupdate /force`, and a restart for computer settings.

**Why did you move CLIENT01 out of the Computers folder?**
New computers land in the default Computers container, which isn't an OU, so you can't link GPOs to it. Moving it into the Staff Computers OU makes the district computer policies apply.

**Why a separate admin account?**
I do day-to-day work as a normal user and admin work as gavin.admin. It limits the damage if my everyday account is compromised, and the logs show which person made each change instead of "Administrator".

**How did you give the help desk password reset rights?**
Delegation of Control on the Staff and Students OUs, giving GG-IT only the reset-password permission. They don't need to be Domain Admins for that.

**What would you change for production?**
At least two domain controllers so sign-in survives one going down. File shares on a separate server, not the DC. Backups, including a system state backup of the DC. DHCP failover. Monitoring. And probably Microsoft Entra Connect if the district uses Microsoft 365.

**Why `.internal` instead of `.local`?**
`.local` clashes with multicast DNS that Macs and printers use. ICANN reserved `.internal` for private networks in 2024, so it's the cleaner choice now.

---

## Troubleshooting scenarios

These are common "what would you do" questions. Answer in steps: what you check first and why.

**"A teacher was added to the right group this morning but still can't open the Staff drive."**
1. Confirm the membership in ADUC (Member Of tab).
2. Group membership is read at sign-in, so have them sign out and back in, or run `klist purge`.
3. If it still fails, check Effective Access on the folder for that user.
4. Check whether the drive map points to the right path.

**"A student's account keeps locking."**
1. Unlock it and check the lockout count and source: `Get-ADUser name -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt`.
2. Usually it's an old password saved somewhere: a phone's school email, a mapped drive with saved credentials, or a second device still signed in.
3. On a real DC, event ID 4740 on the PDC emulator shows which computer caused the lockout.

**"Nobody can sign in this morning and it says the domain isn't available."**
1. Is the DC up? Can you ping it?
2. Are DNS and Netlogon services running on it?
3. Do clients have the DC as their DNS server? (Check DHCP option 006 and one client's `ipconfig /all`.)
4. Is the time right on the DC? Kerberos fails with more than 5 minutes of clock difference.

**"A PC says the trust relationship with the domain failed."**
The computer account password no longer matches AD, often after restoring an old image or snapshot. Sign in with a local admin account, then `Test-ComputerSecureChannel -Repair -Credential PCUSD\gavin.admin`, or remove the PC from the domain and rejoin it.

**"A new PC gets a 169.254 address."**
It didn't get an answer from DHCP. Check the cable or VLAN, that the DHCP scope is active and has free addresses, and that the server is authorized in AD.

---

## Your own stories (fill these in after you build)

Interviewers often ask "tell me about a time you solved a problem." Use your build log. Structure each story in four parts: the **situation**, the **task**, the **action** you took, and the **result** (STAR).

**Story 1: a problem you hit while building**

- Situation:
- What I needed to do:
- What I tried, in order:
- What fixed it, and how I confirmed it:
- What I'd do differently:

**Story 2: a help desk ticket you worked in the lab**

- Situation:
- What I needed to do:
- What I did (GUI and PowerShell):
- Result:

**Story 3: something you automated**

- Situation: e.g. creating 20 users by hand would be slow and error-prone
- What I built:
- How I tested it (`-WhatIf` first):
- Result:

---

## Questions to ask them

Good questions show you're thinking about the job, not just the offer.

- How many sites and devices does the IT team support, and how is the team split?
- What does a typical week of tickets look like? What are the most common ones?
- Are you mostly on-premises Active Directory, Microsoft Entra ID, Google Workspace, or a mix?
- How do new technicians learn the environment in the first month?
- What does growth look like from this role? Do technicians move into systems or network work?

---

## Words to use carefully

- Say **"in my lab"**, not "at work", for anything you did here.
- Say **"I configured"** or **"I built"** only for what you did yourself. If you ran a provided script, say you ran it and explain what it does.
- If you don't know an answer: "I haven't worked with that yet. In my lab I'd start by [closest thing you do know]." That's a good answer for an entry-level role.
