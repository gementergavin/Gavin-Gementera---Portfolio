# Help Desk Ticket Portfolio

20 practice help desk tickets, 9 knowledge base articles and a set of canned responses for **Pacific Crest Unified School District** (fictional), worked in **osTicket**, a free, open-source ticketing system I installed on my PC.

These are practice tickets, not real support work. They're based on common school district requests. 13 of them are lab tickets (the "Done in lab" column): I reproduce the problem and fix it in my [Active Directory lab](../04_Active-Directory-Home-Lab), [school network design](../07_School-Network-Packet-Tracer), [device tracker](../08_Chromebook-Device-Tracker) or on my own PC, and attach a screenshot to the ticket.

## What's here

| Folder | Contents |
|---|---|
| [tickets/tickets.csv](tickets/tickets.csv) | All 20 tickets: requester, category, priority, resolution, time, escalation, KB link |
| [tickets/ticket-writeups.md](tickets/ticket-writeups.md) | 6 tickets written up in full, step by step |
| [kb](kb) | Knowledge base articles for users and help desk staff |
| [templates/canned-responses.md](templates/canned-responses.md) | Saved replies: received, need info, escalated, working as designed, outage update, resolved |
| [setup/osticket-setup.md](setup/osticket-setup.md) | How I installed and configured osTicket (XAMPP on Windows) |
| [screenshots](screenshots) | osTicket queue, ticket threads, SLA plans |

## Ticket summary

| Category | Tickets | Examples |
|---|---|---|
| Accounts | 7 | Lockouts, password resets, new hire, leaver, MFA on a new phone, repeated lockouts traced to a phone |
| Access | 3 | Missing S: drive, "can't save" (working as designed), access request declined (least privilege) |
| Network | 3 | Guest Wi-Fi DHCP pool full, blocked website, whole classroom offline |
| Devices | 3 | Chromebook won't power on, slow PC, Chromebook cart updates |
| Classroom AV, Printing, Software, Security | 4 | Projector no signal, stuck print queue, software install, phishing response |

| Priority | Meaning | Target |
|---|---|---|
| P1 Critical | Many users down, or a security incident | Resolve within 4 hours |
| P2 High | One person can't work | Within 1 business day |
| P3 Normal | Problem with a workaround | Within 3 business days |
| P4 Low | Request or minor issue | Within 5 business days |

## Knowledge base

| Article | For |
|---|---|
| [KB-001 Password reset and account unlock](kb/KB-001-password-reset-and-unlock.md) | Help desk (includes identity verification and tracing repeated lockouts) |
| [KB-002 Shared drive missing or access denied](kb/KB-002-mapped-drive-missing.md) | Help desk |
| [KB-003 Connecting to district Wi-Fi](kb/KB-003-wifi-connection.md) | Everyone |
| [KB-004 Projector shows "No signal"](kb/KB-004-classroom-display-no-signal.md) | Teachers |
| [KB-005 Printer not printing](kb/KB-005-printer-not-printing.md) | Help desk |
| [KB-006 Chromebook won't turn on or charge](kb/KB-006-chromebook-wont-turn-on.md) | Students, teachers, help desk |
| [KB-007 MFA on a new phone](kb/KB-007-mfa-new-phone.md) | Staff |
| [KB-008 New and leaving staff checklists](kb/KB-008-onboarding-offboarding.md) | Help desk |
| [KB-009 Suspicious email (phishing)](kb/KB-009-reporting-phishing.md) | Everyone |

## Interview talking points

- **Verify before you reset.** Every password or MFA ticket starts with identity verification. Social engineering targets help desks.
- **Troubleshoot from the simplest cause:** one user or many? What changed? A `169.254` address points to DHCP, not signal strength.
- **Escalate with evidence:** what I checked, what I found, and my best guess, so the next person doesn't start over (HD-1009).
- **"Working as designed" is still customer service:** explain why and show the right way (HD-1016).
- **Write it down:** a fix that happens twice becomes a KB article.

## Skills shown

Ticket triage and prioritization, SLAs, escalation, Active Directory account support, Windows troubleshooting, printing, Wi-Fi and DHCP basics, phishing response, writing for non-technical users, osTicket administration.
