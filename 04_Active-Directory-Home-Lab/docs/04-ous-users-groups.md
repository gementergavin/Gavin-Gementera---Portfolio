# 4. OUs, users and groups

Do these on **DC01** as `PCUSD\Administrator`.

## 4.1 OUs, groups and your admin account

**Script:** `.\4-New-PcusdStructure.ps1` (asks for a password for `PCUSD\gavin.admin`)

```
pcusd.internal
└── PCUSD
    ├── Staff
    │   ├── Teachers
    │   ├── Office
    │   └── IT
    ├── Students
    ├── Computers
    │   ├── Staff Computers
    │   └── Student Computers
    ├── Groups
    └── Disabled Accounts
```

**Why OUs:** Group Policy links to OUs, and help desk rights can be delegated per OU. Separating students from staff (and student PCs from staff PCs) lets each get different rules.

**GUI way:** Active Directory Users and Computers (ADUC) > right-click `pcusd.internal` > New > Organizational Unit. Repeat for each OU. For groups: right-click `Groups` > New > Group, choose the scope (Global or Domain local) and type Security.

**Groups follow AGDLP:** user **A**ccounts go in **G**lobal role groups (`GG-Teachers`), which go in **D**omain **L**ocal permission groups (`DL-Staff-Share-Modify`), which get **P**ermissions on folders. When a new teacher starts, adding them to `GG-Teachers` gives them every teacher permission at once.

From now on, log in as **`PCUSD\gavin.admin`** for admin work instead of the built-in Administrator. Using a named admin account means every change in the logs shows who made it.

## 4.2 Create users from a CSV

Use the toolkit from [project 05](../../05_PowerShell-Admin-Toolkit). Copy the whole `05_PowerShell-Admin-Toolkit` folder to DC01, then:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module .\AdminTools\AdminTools.psd1

# Preview first: shows what would be created, changes nothing
New-BulkADUser -CsvPath .\data\new-users.csv -WhatIf

# Create the accounts. Temporary passwords are saved to a CSV in your Documents folder.
New-BulkADUser -CsvPath .\data\new-users.csv
```

Each user goes in the OU for their role, joins their role group, and must change the temporary password at first sign-in.

**GUI way (do at least one by hand):** ADUC > `Staff\Teachers` > New > User. Fill in the name and logon name, set a password, check **User must change password at next logon**. Then right-click the user > Add to a group > `GG-Teachers`.

## 4.3 Delegate password resets to the help desk

Help desk staff shouldn't be Domain Admins just to reset passwords.

1. ADUC > right-click the **Students** OU > **Delegate Control** > Next.
2. Add `GG-IT` > Next.
3. Check **Reset user passwords and force password change at next logon** > Next > Finish.
4. Repeat on the **Staff** OU.

Now members of `GG-IT` can reset passwords in those OUs without being Domain Admins. This is the principle of least privilege.

**Check:**

```powershell
Get-ADUser -Filter * -SearchBase 'OU=PCUSD,DC=pcusd,DC=internal' |
    Select-Object Name, SamAccountName, Enabled | Sort-Object Name
Get-ADGroupMember GG-Teachers | Select-Object Name
```

**What you should see:** 21 accounts (the 20 from the CSV plus `gavin.admin`), all `Enabled = True`, with usernames like `maria.lopez`. Then the six teachers:

```
Name
----
Aaliyah Brooks
David Chen
Marcus Bennett
Maria Lopez
Priya Shah
Sofia Ramirez
```

(The order may differ.) In ADUC, open `DL-Staff-Share-Modify` > **Members**: you should see the three groups `GG-Teachers`, `GG-Office` and `GG-IT`, not individual people. That's AGDLP.

Run `.\7-Test-LabHealth.ps1` again: the **Structure** and **Users** sections should now pass.

## Screenshots for this step

- `04-aduc-ou-tree.png`: ADUC showing the OU tree with some users in Teachers and Students
- `04-bulk-import-whatif.png`: PowerShell window with the `-WhatIf` preview
- `04-group-membership.png`: a user's Member Of tab showing their role group
- `04-delegation-wizard.png`: the Delegate Control wizard's task page
