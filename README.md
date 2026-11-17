# Gavin Gementera — IT & Data Portfolio

Hands-on projects for help desk, IT support and junior systems administration roles. I have a B.S. in Business Administration (Information Systems) from CSU Fullerton (2025).

Most projects share one fictional school district, **Pacific Crest Unified School District**, so they connect: the PowerShell toolkit creates the users in the Active Directory lab, the help desk tickets are solved in the lab and the network design, and the device tracker holds the Chromebook from ticket HD-1006.

## IT projects

| Project | What it is | Tools |
|---|---|---|
| [Active Directory Home Lab](./04_Active-Directory-Home-Lab) | Windows Server domain controller (AD DS, DNS, DHCP) and a domain-joined Windows 11 PC in VirtualBox: OUs, groups, Group Policy, file share permissions, help desk practice | Windows Server 2025, Active Directory, Group Policy, VirtualBox |
| [PowerShell Admin Toolkit](./05_PowerShell-Admin-Toolkit) | Module for bulk user creation from CSV, password resets, expiring-password and inactive-account reports, and a PC health report; Pester tests | PowerShell, Active Directory module, Pester |
| [Help Desk Ticket Portfolio](./06_Help-Desk-Ticket-Portfolio) | 20 practice tickets, 9 knowledge base articles and canned responses, worked in osTicket | osTicket, ticket triage, SLAs, technical writing |
| [School Network Design](./07_School-Network-Packet-Tracer) | Campus network with VLANs, inter-VLAN routing, DHCP, ACLs, NAT, port security and SSH, with configs and a 20-test plan | Cisco Packet Tracer, Cisco IOS |
| [Chromebook Device Tracker](./08_Chromebook-Device-Tracker) | Web app for checking devices out to students, repairs and overdue reports; 32 tests | Python, Flask, SQLite |

## Data projects

| Project | What it is | Tools |
|---|---|---|
| [Inventory Management System](./03_Inventory-Management-System) | Command-line app that tracks stock across 4 locations, rejects bad input, flags low stock, and logs every change; 11 unit tests | Python, SQLite, SQL |
| [Program Performance Dashboard](./02_BI-Performance-Dashboard) | Excel dashboard on 500 sample records: KPIs, top programs, regions, quarterly trend, charts. Every number is a live formula | Excel |
| [IT Risk Register & Data Governance Framework](./01_Risk-Governance-Framework) | 18 IT risks scored by likelihood and impact, a 5x5 heat map, and a 2-page data governance policy | Excel, technical writing |

## Try the code projects

Python 3.9+ is all you need for the inventory app; the device tracker also needs Flask.

```bash
git clone https://github.com/gementergavin/Gavin-Gementera---Portfolio.git
cd Gavin-Gementera---Portfolio

# Inventory app
cd 03_Inventory-Management-System && python inventory_app.py

# Device tracker (from the repo folder)
cd 08_Chromebook-Device-Tracker
pip install -r requirements.txt && python seed.py && python app.py   # open http://127.0.0.1:5000
```

The PowerShell toolkit runs on Windows: see its [README](./05_PowerShell-Admin-Toolkit) for the health report (any PC) and the Active Directory functions (lab domain controller).

## Excel projects

Download the `.xlsx` files and open them in Excel or Google Sheets. GitHub can't preview Excel files.
