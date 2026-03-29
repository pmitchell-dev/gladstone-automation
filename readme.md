# ?? Gladstone Hub & Spoke Automation

This repository contains the master automation suite for the **Gladstone Pi 5 Communication Hub** and its associated **Webhost Nodes**. It is designed to be a "Universal Installer" that configures itself based on the server's designated role.

---

## ??? Architecture Overview

The Gladstone ecosystem follows a **Hub & Spoke** model:
* **The Hub (RPi5):** The central brain. Manages printer monitoring, network speed audits, local backups, and relays commands to other nodes.
* **The Nodes (Laptop/VM):** Specialized servers (like Webhosts) that stay lean and focused on specific tasks, while reporting health back to the Hub.



[Image of a hub and spoke network topology]


---

## ?? One-Command Installation

To deploy or fully update a server, run the following command from your home directory:

```bash
cd ~ && rm -rf ~/scripts && git clone [https://github.com/legendary034/pi5-scripts.git](https://github.com/legendary034/pi5-scripts.git) ~/scripts && cd ~/scripts && ./install.sh --[MODE]
Available Modes:--ntfy: Configures the server as the Communication Hub. (Installs speedtest-cli, printer tools, and master listener).--webhost: Configures the server as a Web Node. (Minimal footprint, heartbeat only).?? Server Identity (~/.gladstone_mode)Upon installation, a hidden file is created at ~/.gladstone_mode. This file acts as the server's "ID Card."Sync & Update: These scripts read this file to determine which services to restart and how to format notifications.Smart Reinstall: Once the mode is set, you can run ./install.sh without any flags; it will automatically remember its previous identity.??? Core Command RegistryCommandAliasPurposedbdashboardView system vitals, printer status, and network speeds.relayrelaySend formatted ntfy messages to specific channels.syncsyncPush local changes to GitHub with a mode-aware heartbeat.updateupdatePull GitHub changes and trigger a Smart Refresh of services.reinstallreinstallRun the Gladstone bootstrap to fix permissions or apply updates.?? System MaintenanceThe "5-Strike" WatchdogThe pi_services_manager.sh runs every 5 minutes. If a persistent service (like the ntfy_listener) fails, the watchdog will attempt 4 silent restarts. On the 5th failure, it sends an Urgent Alert to your phone including a snippet of the error log.The Naked ResetTo completely wipe the Gladstone environment from a machine, run:Bashbash ~/scripts/cleanup_test.sh
Note: This will clear the crontab, delete the identity file, and wipe all scripts/logs/backups.?? Directory Structure~/scripts/: Core automation logic.~/scripts/logs/: All runtime telemetry (Excluded from GitHub).~/scripts/backup/: Daily local ZIP rotations (Keeps last 2).~/printer_data/: Scraped HTML data from the Brother printer.