# 7. File shares and permissions

**Script (on DC01):** `.\5-New-PcusdShares.ps1`

| Share | Path | Who can do what (NTFS) |
|---|---|---|
| `\\DC01\Staff` | `C:\Shares\Staff` | All staff: Modify |
| `\\DC01\Students` | `C:\Shares\Students` | Teachers: Modify. Students: Read |
| `\\DC01\IT` | `C:\Shares\IT` | IT: Modify |

Administrators and SYSTEM have Full Control on all three.

## How the permissions work

A share has two permission layers, and Windows uses the **more restrictive** one:

- **Share permissions:** set broad (Authenticated Users: Change).
- **NTFS permissions:** set narrow, and only through `DL-` groups. This is where the real control is.

Inheritance from `C:\` is removed so the default "Users: Read" entry doesn't leak access. **Access-based enumeration** hides folders a user can't open.

**GUI way:** right-click the folder > Properties > **Security** > Advanced > **Disable inheritance** > Remove all inherited permissions > Add the groups. Then the **Sharing** tab > Advanced Sharing > Share this folder > Permissions.

## Test it

On CLIENT01:

| Signed in as | Try | Expected |
|---|---|---|
| Teacher | Create a file in `\\DC01\Students` | Works |
| Student | Open `\\DC01\Students` | Can open files |
| Student | Create a file in `\\DC01\Students` | Access denied |
| Student | Browse `\\DC01` | Staff and IT shares not visible (access-based enumeration) |
| Office staff | Open `\\DC01\IT` | Access denied |

Check effective access on DC01: folder > Properties > Security > Advanced > **Effective Access** > select a user > View effective access.

## Screenshots for this step

- `07-ntfs-permissions.png`: Advanced Security Settings for `C:\Shares\Students`
- `07-effective-access.png`: Effective Access for a student
- `07-access-denied.png`: a student trying to save to the Students share
