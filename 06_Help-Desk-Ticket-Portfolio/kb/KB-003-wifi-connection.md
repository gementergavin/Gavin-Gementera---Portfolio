# KB-003: Connecting to district Wi-Fi

**Audience:** staff, students, visitors · **Tickets:** HD-1009

| Network | Who | How to sign in |
|---|---|---|
| PCUSD-Staff | Staff | District username and password |
| PCUSD-Student | Students | District username and password |
| PCUSD-Guest | Visitors | Open; accept the terms page. Internet only, no access to district systems |

## For users

1. Turn Wi-Fi off and on, then pick the right network from the list.
2. Use the **district username** (for example `maria.lopez`), not your email address, unless the screen asks for email.
3. On a phone, choose **Do not validate** for the certificate only if IT tells you to.
4. Still stuck? Note the time, the room, and any error message, and submit a ticket.

## For help desk

1. **Check the address.** Windows: `ipconfig`. A `169.254.x.x` address means the device got no address from DHCP.
   - One device: forget the network and reconnect, or restart.
   - Many devices on the same network: the DHCP pool may be full or the network is down. **Escalate to the network administrator** with the network name, building and time (HD-1009).
2. **Has an address but no internet:** `ping 8.8.8.8` (internet) and `nslookup google.com` (DNS). If ping works but nslookup fails, it's DNS.
3. **One website blocked, others work:** content filter. Send the URL and a screenshot to the network administrator (HD-1010).
4. **Guest network and district sites:** guests can't reach district servers on purpose (see the [school network design](../../07_School-Network-Packet-Tracer)).
