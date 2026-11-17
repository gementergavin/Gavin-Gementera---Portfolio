# Setting up osTicket on a Windows PC

osTicket is a free, open-source help desk system used by many schools and small businesses. These steps run it on your own Windows PC with XAMPP (Apache, PHP and MySQL/MariaDB in one installer). Allow about an hour.

## 1. Install XAMPP

1. Download XAMPP for Windows from **apachefriends.org**. Pick a build with **PHP 8.2 or newer**; check osTicket's current requirements on its download page first.
2. Install to `C:\xampp` (the default). You only need **Apache, MySQL, PHP and phpMyAdmin**.
3. Open the **XAMPP Control Panel** and click **Start** for **Apache** and **MySQL**. Both should turn green.
4. Browse to `http://localhost/dashboard`. The XAMPP page means Apache works.

If Apache won't start, another program is using port 80; the Control Panel's log shows which.

## 2. Create the database

1. Browse to `http://localhost/phpmyadmin`.
2. **User accounts > Add user account:** user `osticket`, host `localhost`, a strong password, and check **Create database with same name and grant all privileges**.

Giving osTicket its own database user (not `root`) is least privilege again.

## 3. Install osTicket

1. Download the latest osTicket release from **osticket.com** (Download > osTicket core).
2. Unzip it. Copy the contents of its **`upload`** folder to `C:\xampp\htdocs\osticket`.
3. In `C:\xampp\htdocs\osticket\include`, rename **`ost-sampleconfig.php`** to **`ost-config.php`**.
4. Browse to `http://localhost/osticket/setup`. Fix anything the prerequisite check marks red (usually by enabling a PHP extension in `C:\xampp\php\php.ini`, then restarting Apache).
5. Fill in the form:
   - Helpdesk name: `PCUSD IT Help Desk`; default email: anything ending in `@pcusd.internal`
   - Your admin account: your name, `gavin.admin`
   - Database: host `localhost`, database `osticket`, user `osticket`, your password
6. After "Congratulations": **delete `C:\xampp\htdocs\osticket\setup`** and make `ost-config.php` **read-only** (right-click > Properties > Read-only). osTicket warns you until both are done.

Staff panel: `http://localhost/osticket/scp`. User portal: `http://localhost/osticket`.

## 4. Configure it like a district help desk

In the staff panel (**Admin Panel**):

| Area | Set up |
|---|---|
| Agents > Departments | `IT Help Desk`, `Network`, `Device Repair` |
| Agents | Yourself, plus a second agent (for example "Jessica Morales, Network Administrator") to escalate to |
| Manage > Help Topics | Accounts and passwords, Access and shared drives, Classroom AV, Devices, Printing, Network and Wi-Fi, Software requests, Security |
| Manage > SLA Plans | P1 Critical: 4 hours · P2 High: 8 hours · P3 Normal: 72 hours · P4 Low: 120 hours |
| Manage > Canned Responses | Paste the replies from [templates/canned-responses.md](../templates/canned-responses.md) |
| Knowledgebase > FAQs | Add the articles from the [kb](../kb) folder |

## 5. Work the tickets

For each ticket in [tickets/tickets.csv](../tickets/tickets.csv):

1. Open the user portal and submit it **as the requester** (create the user first under Users).
2. Switch to the staff panel and work it **as the agent**: set priority and help topic, reply with a canned response, add internal notes for each step, escalate (assign to Network) where the CSV says so, and close it with the resolution.
3. Where "Done in lab" says Yes, do the fix in the AD lab or Packet Tracer and attach a screenshot to the ticket.

Take screenshots for this project's [screenshots](../screenshots) folder: the open-ticket queue, one full ticket thread, an escalated ticket, the SLA plans, and the dashboard.
