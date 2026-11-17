# Detailed ticket write-ups

Six tickets written up the way they'd appear in osTicket: the request, every step taken, and the closing note. These are practice tickets for a fictional district; those marked "Done in lab" were reproduced in my [AD lab](../../04_Active-Directory-Home-Lab) or [network design](../../07_School-Network-Packet-Tracer).

---

## HD-1004: Can't open the Staff drive (S:)

| Field | Value |
|---|---|
| Requester | Sofia Ramirez, Math Teacher, Pacific Crest High |
| Priority | P3 Normal (one user, has a workaround) |
| Category | Access |
| Done in lab | Yes |

**Request:** "I started this week and I don't see the S: drive other teachers use. When I type `\\DC01\Staff` it says access denied."

**Work notes:**
1. Confirmed by phone; she can sign in and use other resources, so the account works.
2. `Get-ADPrincipalGroupMembership sofia.ramirez` showed only **Domain Users**. Teachers need `GG-Teachers`, which grants access through `DL-Staff-Share-Modify` and gets the drive map GPO.
3. Checked the new-hire ticket (HD-1007 pattern): the account was created by hand, and the group step was missed.
4. Added her to `GG-Teachers`. Asked her to sign out and back in (group membership is read at sign-in).
5. She signed back in: S: appeared and she could open and save files.

**Resolution:** added missing role group. **Root cause:** manual account creation skipped a step. **Prevention:** create accounts with the bulk script, which always adds the role group.

**Time:** 20 minutes · **KB:** KB-002

---

## HD-1009: Visitor's laptop gets no internet on Guest Wi-Fi

| Field | Value |
|---|---|
| Requester | Linda Okafor, for a visiting presenter |
| Priority | P2 High (presentation starting in 30 minutes) |
| Category | Network |
| Escalated to | Network administrator |
| Done in lab | Yes (Packet Tracer) |

**Request:** "Our assembly speaker can't get online on the guest Wi-Fi."

**Work notes:**
1. Went to the gym. Laptop connected to PCUSD-Guest, but `ipconfig` showed `169.254.x.x`: it got no DHCP address.
2. My phone also failed on PCUSD-Guest; it worked on PCUSD-Staff. So the problem was guest-wide, not the laptop.
3. About 400 students were in the assembly, and many phones had joined the guest network. A /24 guest pool has about 240 usable addresses, with 8-day leases from earlier events still held.
4. **Workaround:** connected the presenter's laptop with a cable to a staff port with the teacher's approval. Presentation started on time.
5. **Escalated** to the network administrator with: network name, building, time, the 169.254 address, and my pool-exhaustion theory.
6. Network admin confirmed the pool was full and shortened guest leases to 4 hours.

**Resolution:** guest DHCP lease time shortened. **Lesson:** a 169.254 address points to DHCP, not Wi-Fi signal.

**Time:** 40 minutes · **KB:** KB-003

---

## HD-1014: Phishing email "verify your payroll"

| Field | Value |
|---|---|
| Requester | Aaliyah Brooks, English Teacher, Harbor Middle |
| Priority | P1 Critical (security, many users) |
| Category | Security |
| Escalated to | Network administrator |

**Request:** reported through the Report Phishing button: "This looks fake. It says I'll miss my paycheck if I don't verify."

**Work notes (timeline):**
- **8:12** Report received. Sender display name "Payroll Dept" but the address was an outside free email domain. Link pointed to a look-alike sign-in page.
- **8:15** Escalated to the network administrator and started a message trace: 42 staff received it.
- **8:25** Sign-in logs: one staff member entered a password on the fake page at 8:03.
- **8:28** Reset that user's password (KB-001), signed them out of all sessions, confirmed no new MFA method was added.
- **8:35** Network admin blocked the sender and the link domain and removed the message from all mailboxes.
- **8:45** Sent an all-staff warning with a screenshot and the reporting steps.

**Resolution:** contained within 33 minutes of the report. Thanked the reporter; her quick report limited the damage to one account.

**Time:** 1.5 hours · **KB:** KB-009

---

## HD-1015: Classroom PC is very slow

| Field | Value |
|---|---|
| Requester | Priya Shah, Computer Science Teacher |
| Priority | P4 Low (works, but slowly) |
| Category | Devices |
| Done in lab | Yes (on my own PC) |

**Work notes:**
1. Ran `Get-SystemHealthReport` from my [PowerShell toolkit](../../05_PowerShell-Admin-Toolkit). Warnings: **C: Critical, 4% free** and **restart pending, up 41 days**.
2. With her permission, removed temp files (`%TEMP%`, Disk Cleanup) and moved old video files from Downloads to her S: drive.
3. Installed pending updates and restarted at the end of the day.
4. Re-ran the report: 31% free, no warnings. She confirmed it was fast the next morning.

**Resolution:** freed disk space and restarted. **Prevention:** suggested a monthly restart reminder.

**Time:** 35 minutes

---

## HD-1017: Whole classroom offline

| Field | Value |
|---|---|
| Requester | Marcus Bennett, Room 12, Crestview Elementary |
| Priority | P1 Critical (24 devices, class in session) |
| Category | Network |
| Escalated to | Network administrator (notified) |
| Done in lab | Yes (Packet Tracer) |

**Work notes:**
1. Sent an outage notice to the principal (template "Outage update").
2. One classroom PC: network cable connected but **no link light**. Another room on the same hallway was fine. That points to the room's access switch, not the whole network.
3. Checked the network closet: the access switch had **no power**. The custodian had unplugged the power strip to vacuum.
4. Plugged it back in. The switch booted in about 3 minutes and devices reconnected.
5. Labeled the power strip "Network: do not unplug" and let facilities know.
6. Sent the closure update.

**Resolution:** restored power to the access switch. Downtime: 18 minutes.

**Time:** 30 minutes

---

## HD-1019: Locked out every morning

| Field | Value |
|---|---|
| Requester | Maria Lopez, 3rd Grade Teacher |
| Priority | P2 High (can't work until unlocked) |
| Category | Accounts |
| Done in lab | Yes |

**Work notes:**
1. Third lockout this week, always around 7:30 AM. She changed her password last Friday.
2. On DC01, filtered the Security log for **Event ID 4740**: each lockout listed "Caller Computer Name" as her phone, not her classroom PC.
3. Her phone's email app still had the old password and retried it every few minutes, locking the account.
4. Walked her through updating the password in the phone's email account. Unlocked the account (KB-001).
5. Checked again the next two mornings: no lockouts.

**Resolution:** updated saved password on phone. **Lesson:** repeated lockouts usually come from a device with an old saved password; event 4740 shows which one.

**Time:** 45 minutes · **KB:** KB-001
