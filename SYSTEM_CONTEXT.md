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
| `install.sh` | `775 (-rwxrwxr-x)` | **Bootstrap:** Installs dependencies (jq, curl, zip, speedtest) & enforces permissions. |
| `pi_rebuild.sh` | `775 (-rwxrwxr-x)` | **Provisioner:** Sets up folders, Cron, and Aliases. |
| `pi_services_manager.sh`| `775 (-rwxrwxr-x)` | **Watchdog:** Restarts the ntfy listener every 5 mins. |
| `pi-dashboard.sh` | `775 (-rwxrwxr-x)` | **UI (db):** Displays vitals, printer status, network speeds, and cloud sync info. |
| `pi_backup.sh` | `775 (-rwxrwxr-x)` | **Backup:** Daily midnight ZIP of scripts (Keeps only 2 most recent). |
| `net_speed.sh` | `775 (-rwxrwxr-x)` | **Monitor:** Runs background speedtests every 6 hours. |
| `ntfy_listener.sh` | `775 (-rwxrwxr-x)` | **Service:** Translates ntfy pings into shell commands. |
| `pi_sync.sh` | `775 (-rwxrwxr-x)` | **Cloud:** Pushes code to GitHub. Logs to `logs/last_sync.log`. |
| `pi_update.sh` | `775 (-rwxrwxr-x)` | **Cloud:** Pulls GitHub updates & refreshes environment. |
| `get_printer_status.sh` | `775 (-rwxrwxr-x)` | **Scraper:** Downloads raw HTML from Brother printer. |
| `printer_alert.sh` | `775 (-rwxrwxr-x)` | **Alert:** Notifies phone of Jams/Low Toner. |
| `aliases.sh` | `775 (-rwxrwxr-x)` | **Logic:** Shorthand commands for `.bashrc`. |
| `.gitignore` | `664 (-rw-rw-r--)` | **Shield:** Excludes `logs/` and `backup/` from GitHub. |

---

## ?? Local Storage Management (Excluded from GitHub)
### ?? Logs (`~/scripts/logs/`)
- `rebuild.log`: Provisioning history.
- `ntfy.log`: Inbound command history.
- `net_speed.log`: Result of the latest speedtest.
- `last_sync.log`: Timestamp of the last successful GitHub push.
- `services_manager.log`: Watchdog activity.

### ?? Backups (`~/scripts/backup/`)
- Local `.zip` archives of the entire scripts directory.
- Strictly maintained rotation: **Only the 2 most recent backups are kept.**

---

## ?? Scheduled Tasks (Crontab)
```bash
# Every 4 hours: Scrape & Alert
0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh

# Every 6 hours: Network Speedtest
0 */6 * * * /home/pi/scripts/net_speed.sh

# Daily at Midnight: Local ZIP Backup
0 0 * * * /home/pi/scripts/pi_backup.sh

# Every 5 mins: Watchdog check
*/5 * * * * /home/pi/scripts/pi_services_manager.sh

# Daily Heartbeat at Noon
0 12 * * * curl -d "Pi 5 Daily Heartbeat: Healthy" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts

# Boot: Start Listener
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &