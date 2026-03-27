# 🏰 Gladstone Pi 5 Automation Hub
**Version:** 1.2.0 (March 2026)  
**Location:** Gladstone, MO  
**Core Domain:** localrepo.net

This repository contains the full automation stack for the **Gladstone Pi 5**, managing everything from Brother printer telemetry to real-time flight tracking and ntfy-based remote command execution.

---

## 🚀 Quick Start (Recovery)
To restore the Gladstone environment on a "Naked" machine or a fresh Raspberry Pi OS install:

1. **Clone the Repository:**
   ```bash
   git clone [https://github.com/yourusername/scripts.git](https://github.com/yourusername/scripts.git) ~/scripts
   cd ~/scripts
Run the Bootstrap:Bashbash install.sh
Refresh your Environment:Bashsource ~/.bashrc
db
🛠️ System Architecture1. Command & Controlntfy_listener.sh: The primary background service. Listens on Port 8080 for remote commands (e.g., health, flight, sync).pi_services_manager.sh: The Watchdog. Runs every 5 minutes via Cron to ensure the listener is alive.aliases.sh: Injects shorthand commands into .bashrc for local management.2. Printer Intelligence (Brother HL-L2405W)get_printer_status.sh: Scrapes the printer’s web interface (IP: 192.168.50.56).printer_alert.sh: Scans for "Toner Low," "No Paper," or "Jam" and sends high-priority ntfy alerts.printer_health.sh: Formats the raw HTML data into a clean percentage-based report.3. Flight Trackingtrack_flight.sh: A dual-stage tracker. Attempts Airlabs (Live Radar) first; falls back to Aviationstack (Schedule) if the plane hasn't taken off.4. Maintenance & Cloudpi_sync.sh: Pushes local changes to GitHub and updates last_sync.log.pi_update.sh: Pulls updates from GitHub and immediately refreshes the local environment.pi_rebuild.sh: The "Provisioner" that sets up directories, permissions, and crontabs.🔑 Manual Configuration RequiredAfter running the bootstrap, ensure the following API keys are updated in track_flight.sh:Airlabs API Key: 4dc4b2db-5edb-432d-b858-50b9aa4e3afdAviationstack API Key: [REDACTED_FOR_SECURITY] (Add your key here)📊 Shorthand Command List (Aliases)CommandActiondbOpens the Gladstone Control Center (Architecture-Aware Dashboard)syncBacks up all scripts to GitHub and logs the heartbeatupdatePulls the latest code from GitHub and refreshes aliasescycleHard-restarts the ntfy listener servicerefreshManually reloads your .bashrc configuration📅 Scheduled Tasks (Crontab)Every 4 Hours (0, 8, 12, 16, 20): Printer Scraping and Alert checking.Every 5 Minutes: Service Watchdog (System Self-Healing).Daily (12:00 PM): Health Heartbeat notification to phone.At Boot: Automatic launch of the ntfy listener.🧹 Cleanup & TestingIf you need to wipe the system for a clean-room test:Bashbash ~/scripts/cleanup_test.sh
This will kill active processes, wipe the ~/scripts folder, clear your crontab, and scrub aliases from your .bashrc.Maintained by Patrick Mitchell Gladstone Pi 5 - LocalRepo.net
### Next Step
Since you’ve got your `sync` alias set up, would you like me to show you the command to commit and push this `README.md` to your GitHub right now?
