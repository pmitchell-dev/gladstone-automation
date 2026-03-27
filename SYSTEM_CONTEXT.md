# ?? Gladstone Pi 5 Master System Context
**Last Updated:** March 27, 2026  
**Environment:** Raspberry Pi 5 / x86 Debian  
**Project:** LocalRepo.net Automation Hub  

---

## ?? Network & Hardware
* **Primary Device:** Raspberry Pi 5 (Gladstone, MO).
* **Target Printer:** Brother HL-L2405W at `192.168.50.56`.
* **Communication:** `ntfy` server running on **Port 8080** (Topic: `patrick_mitch_pi5_x9k2v_alerts`).
* **Cloud Backup:** GitHub Repository synced at `/home/pi/scripts`.

---

## ?? Core File Registry & Permissions
| File | Permissions | Purpose |
| :--- | :--- | :--- |
| `install.sh` | `775 (-rwxrwxr-x)` | **Bootstrap:** Installs dependencies (inc. speedtest-cli) & enforces permissions. |
| `pi_rebuild.sh` | `775 (-rwxrwxr-x)` | **Provisioner:** Sets up folders, Cron (inc. speedtest), and Aliases. |
| `pi_services_manager.sh`| `775 (-rwxrwxr-x)` | **Watchdog:** Restarts the ntfy listener every 5 mins. |
| `pi-dashboard.sh` | `775 (-rwxrwxr-x)` | **UI (db):** Displays vitals, printer status, and network speeds. |
| `net_speed.sh` | `775 (-rwxrwxr-x)` | **Monitor:** Runs background speedtests every 6 hours. |
| `ntfy_listener.sh` | `775 (-rwxrwxr-x)` | **Service:** Translates ntfy pings into shell commands. |
| `pi_sync.sh` | `775 (-rwxrwxr-x)` | **Cloud:** Backs up scripts to GitHub + Heartbeat log. |
| `pi_update.sh` | `775 (-rwxrwxr-x)` | **Cloud:** Pulls GitHub updates & refreshes environment. |
| `get_printer_status.sh` | `775 (-rwxrwxr-x)` | **Scraper:** Downloads raw HTML from Brother printer. |
| `printer_alert.sh` | `775 (-rwxrwxr-x)` | **Alert:** Notifies phone of Jams/Low Toner. |
| `printer_health.sh` | `775 (-rwxrwxr-x)` | **Report:** Formats printer data into % levels. |
| `track_flight.sh` | `775 (-rwxrwxr-x)` | **API:** Dual-stage (Airlabs/Aviationstack) tracker. |
| `aliases.sh` | `775 (-rwxrwxr-x)` | **Logic:** Shorthand commands for `.bashrc`. |
| `cleanup_test.sh` | `775 (-rwxrwxr-x)` | **Reset:** Wipes the system for a "Naked" test. |
| `services.registry` | `664 (-rw-rw-r--)` | **Data:** Config file for the Services Manager. |

---

## ?? Scheduled Tasks (Crontab)
```bash
# Every 4 hours: Scrape & Alert
0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh

# Every 6 hours: Network Speedtest
0 */6 * * * /home/pi/scripts/net_speed.sh

# Every 5 mins: Watchdog check
*/5 * * * * /home/pi/scripts/pi_services_manager.sh

# Daily Heartbeat at Noon
0 12 * * * curl -d "Pi 5 Daily Heartbeat: Healthy" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts

# Boot: Start Listener
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &