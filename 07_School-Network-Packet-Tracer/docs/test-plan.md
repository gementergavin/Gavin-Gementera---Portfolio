# Test plan

Run each test and fill in the **Actual** column. If a result doesn't match, the troubleshooting notes at the bottom list the usual causes.

| # | From | Test | Expected | Actual |
|---|---|---|---|---|
| 1 | STAFF-PC1 | Desktop > IP Configuration > DHCP | Gets 10.10.10.21 or higher, gateway 10.10.10.1, DNS 10.10.40.10 | |
| 2 | STUDENT-PC1 | DHCP | Gets 10.10.20.x, gateway 10.10.20.1 | |
| 3 | GUEST-LAPTOP | DHCP over Wi-Fi | Gets 10.10.30.x, DNS 198.51.100.10 | |
| 4 | STAFF-PC1 | `ping 10.10.40.10` | Replies | |
| 5 | STUDENT-PC1 | `ping 10.10.40.10` | Replies (students can reach the server) | |
| 6 | STAFF-PC1 | `ping <STUDENT-PC1 address>` | Replies (staff can reach students; the student's echo-reply is allowed) | |
| 7 | STUDENT-PC1 | `ping <STAFF-PC1 address>` | Fails: "Destination host unreachable" from 10.10.20.1 (ACL STUDENTS-IN) | |
| 8 | STUDENT-PC1 | `ping 10.10.99.2` (SW-CORE management) | Fails (students can't reach management) | |
| 9 | IT-PC | `ssh -l netadmin 10.10.99.3` | SSH login to SW-ACCESS-1 | |
| 10 | STUDENT-PC1 | Web Browser > `http://portal.pcusd.internal` | PCUSD Staff Portal page (DNS and HTTP work) | |
| 11 | STUDENT-PC1 | Web Browser > `http://www.example.test` | Public website page (NAT to the internet works) | |
| 12 | R1 | `show ip nat translations` right after test 11 | A translation from 10.10.20.x to 203.0.113.2 | |
| 13 | GUEST-LAPTOP | `ping 198.51.100.10` | Replies (internet works) | |
| 14 | GUEST-LAPTOP | `ping 10.10.40.10` | Fails (guests can't reach district systems) | |
| 15 | GUEST-LAPTOP | Web Browser > `http://www.example.test` | Public website page | |
| 16 | R1 | `show access-lists` | Match counts increase on the deny lines after tests 7, 8 and 14 | |
| 17 | SW-ACCESS-2 | Plug two other PCs into Fa0/1 one after another (after STUDENT-PC1) and ping from each | The port remembers 2 MAC addresses; the third device's traffic is dropped and the violation count goes up (`show port-security interface fa0/1`) | |
| 18 | SW-ACCESS-2 | `show interfaces trunk` | Fa0/24 trunking, native VLAN 1000, VLANs 10,20,30,40,99,1000 allowed | |
| 19 | SW-CORE | `show spanning-tree vlan 20` | "This bridge is the root" | |
| 20 | R1 | `show ip dhcp binding` | One binding per client from tests 1–3 | |

## Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| PC gets 169.254.x.x | DHCP request not reaching R1 | Access port in the right VLAN? `show vlan brief`. Trunk carrying that VLAN? `show interfaces trunk` |
| PC has an address but can't ping its gateway | Router subinterface | `show ip interface brief` on R1: subinterface up? Correct `encapsulation dot1Q` number? |
| Test 7 succeeds (it shouldn't) | ACL not applied | `show ip interface g0/0/1.20` should list `Inbound access list is STUDENTS-IN` |
| Test 6 fails | ACL too strict | STUDENTS-IN must permit `echo-reply` and `established` before its deny line |
| Test 11 fails, test 10 works | NAT or ISP | `show ip nat translations`, `ip nat inside/outside` on the right interfaces, default route on R1 |
| Can't SSH | Keys not generated | `show ip ssh` on the switch; repeat the `crypto key generate rsa` step |
