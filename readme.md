This `README.md` is designed to be the "source of truth" for your GitHub repository. It ties together the **Bootstrap**, **Rebuild**, **Monitoring**, and **Cleanup** scripts we've finalized, making it easy for you (or a fresh instance of me) to understand the Gladstone architecture at a glance.

***

# 🏰 Gladstone Pi 5 Automation Hub
**Version:** 1.2.0 (March 2026)  
**Location:** Gladstone, MO  
**Core Domain:** `localrepo.net`

This repository contains the full automation stack for the **Gladstone Pi 5**, managing everything from Brother printer telemetry to real-time flight tracking and ntfy-based remote command execution.

---

## 🚀 Quick Start (Recovery)
To restore the Gladstone environment on a "Naked" machine or a fresh Raspberry Pi OS install:

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yourusername/scripts.git ~/scripts
   cd ~/scripts
   ```
2. **Run the Bootstrap:**
   ```bash
   bash install.sh
   ```
3. **Refresh your Environment:**
   ```bash
   source ~/.bashrc
   db
   ```

---

## 🛠️ System Architecture

### 1. Command & Control
* **`ntfy_listener.sh`**: The primary background service. Listens on **Port 8080** for remote commands (e.g., `health`, `flight`, `sync`).
* **`pi_services_manager.sh`**: The Watchdog. Runs every 5 minutes via Cron to ensure the listener is alive.
* **`aliases.sh`**: Injects shorthand commands into `.bashrc` for local management.

### 2. Printer Intelligence (Brother HL-L2405W)
* **`get_printer_status.sh`**: Scrapes the printer’s web interface (IP: `192.168.50.56`).
* **`printer_alert.sh`**: Scans for "Toner Low," "No Paper," or "Jam" and sends high-priority ntfy alerts.
* **`printer_health.sh`**: Formats the raw HTML data into a clean percentage-based report.

### 3. Flight Tracking
* **`track_flight.sh`**: A dual-stage tracker. Attempts **Airlabs (Live Radar)** first; falls back to **Aviationstack (Schedule)** if the plane hasn't taken off.

### 4. Maintenance & Cloud
* **`pi_sync.sh`**: Pushes local changes to GitHub and updates `last_sync.log`.
* **`pi_update.sh`**: Pulls updates from GitHub and immediately refreshes the local environment.
* **`pi_rebuild.sh`**: The "Provisioner" that sets up directories, permissions, and crontabs.

---

## 📊 Shorthand Command List (Aliases)
| Command | Action |
| :--- | :--- |
| `db` | Opens the **Gladstone Control Center** (Architecture-Aware Dashboard) |
| `sync` | Backs up all scripts to GitHub and logs the heartbeat |
| `update` | Pulls the latest code from GitHub and refreshes aliases |
| `cycle` | Hard-restarts the ntfy listener service |
| `refresh` | Manually reloads your `.bashrc` configuration |

---

## 📅 Scheduled Tasks (Crontab)
* **Every 4 Hours:** Printer Scraping and Alert checking.
* **Every 5 Minutes:** Service Watchdog (System Self-Healing).
* **Daily (12:00 PM):** Health Heartbeat notification to phone.
* **At Boot:** Automatic launch of the ntfy listener.

---

## 🧹 Cleanup & Testing
If you need to wipe the system for a clean-room test:
```bash
bash ~/scripts/cleanup_test.sh
```
*This will kill active processes, wipe the `~/scripts` folder, clear your crontab, and scrub aliases from your `.bashrc`.*

---

**Would you like me to add a specific section to this README about the hardware specs of your Pi 5 or the specific API keys required for the flight tracker?**
