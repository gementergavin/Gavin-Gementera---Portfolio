# 6. Group Policy

## 6.1 Create the policies

**Script (on DC01):** `.\6-New-PcusdGPOs.ps1`

| Policy | Linked to | What it does |
|---|---|---|
| Default domain password policy | Domain | 12+ characters, complexity, 10 remembered, lock out for 15 min after 5 wrong tries |
| PCUSD - Students - Block Control Panel | OU=Students | Students can't open Control Panel or Settings |
| PCUSD - Student Computers - Block USB | OU=Student Computers | No USB drives on student PCs |
| PCUSD - All Computers - Logon Banner | OU=Computers | Acceptable use notice before sign-in |

**GUI way (do at least one by hand):** Group Policy Management (`gpmc.msc`) > right-click the **Students** OU > **Create a GPO in this domain, and Link it here** > name it > right-click > Edit > **User Configuration > Policies > Administrative Templates > Control Panel > Prohibit access to Control Panel and PC settings** > Enabled.

## 6.2 Map the S: drive for staff (GUI)

1. GPMC > right-click the **Staff** OU > Create a GPO and link it: `PCUSD - Staff - Map S Drive`.
2. Edit > **User Configuration > Preferences > Windows Settings > Drive Maps** > New > Mapped Drive.
3. Action **Update**, Location `\\DC01\Staff`, Label `Staff`, Drive letter **S:**, Reconnect checked.
4. Run `.\5-New-PcusdShares.ps1` first (step 7) if the share doesn't exist yet.

## 6.3 Test the policies

On CLIENT01:

```
gpupdate /force
gpresult /r
```

`gpresult /r` lists which GPOs applied to the computer and to the user. Things to try:

1. **Staff test:** sign in as a teacher. The S: drive appears. Control Panel opens.
2. **Student test:** sign in as a student. Control Panel shows a "restricted" message.
3. **USB test:** on DC01, move CLIENT01 into `Student Computers`, then on CLIENT01 run `gpupdate /force` and restart. Plug a USB drive into the VM (VirtualBox: Devices > USB). It shows "Access denied".
4. **Lockout test:** type a student's password wrong 5 times. The account locks. Unlock it on DC01 (step 8).
5. **Banner test:** restart CLIENT01. The notice appears before the sign-in screen.

## Screenshots for this step

- `06-gpmc-links.png`: GPMC showing the GPOs linked to each OU
- `06-gpresult.png`: `gpresult /r` on CLIENT01 as a student
- `06-control-panel-blocked.png`: the restriction message
- `06-s-drive.png`: File Explorer with the S: drive as a teacher
- `06-logon-banner.png`: the logon banner

## Troubleshooting

| Problem | Check |
|---|---|
| A policy doesn't apply | Is the user or computer in the OU the GPO is linked to? User settings follow the user's OU; computer settings follow the computer's OU |
| Still not applying | `gpresult /h report.html` and open it: look under "Denied GPOs" for the reason |
| Drive map missing | Does the user have NTFS access to the folder? Is the share name right? |
