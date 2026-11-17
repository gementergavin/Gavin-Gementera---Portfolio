# KB-005: Printer not printing

**Audience:** help desk staff · **Tickets:** HD-1005

## Quick checks (ask the user)

- Is the printer on, with no error on its screen (paper jam, out of paper or toner)?
- Does it print for other people? If **nobody** can print, it's the printer or the print queue. If only **one person** can't, it's their PC.

## Nobody can print: clear the queue

1. Open the print queue (Settings > Bluetooth & devices > Printers > the printer > **Open print queue**). A job showing "Error" or stuck at "Printing" blocks everything behind it.
2. Cancel the stuck job. If it won't cancel, restart the Print Spooler service on the PC or print server that hosts the queue:
   ```powershell
   Stop-Service -Name Spooler -Force
   Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Force
   Start-Service -Name Spooler
   ```
3. Print a test page.

## One person can't print

1. Is the right printer selected (not "Microsoft Print to PDF")?
2. Remove and re-add the printer.
3. Can the PC reach it? `ping <printer IP>`. If not, check the printer's network cable or Wi-Fi.
4. Update or reinstall the printer driver.

## Close the ticket

Note the cause (stuck job, driver, network, hardware) so repeat problems show a pattern. Hardware problems such as jams, fusers or toner go to the copier vendor.
