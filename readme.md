# 🖥️ Gladstone Hub & Spoke Automation

This repository contains the master automation suite for the **Gladstone Pi 5 Communication Hub** and its associated **Webhost Nodes**. It is designed to be a "Universal Installer" that configures itself based on the server's designated role.

---

## 🌐 Architecture Overview

The Gladstone ecosystem follows a **Hub & Spoke** model:
* **The Hub (RPi5):** The central brain. Manages printer monitoring, network speed audits, local backups, and relays commands to other nodes.
* **The Nodes (Laptop/VM):** Specialized servers (like Webhosts) that host application stacks, while reporting health back to the Hub.

---

## ⚡ One-Command Installation

To deploy or fully update a server, run the following command from your home directory:

```bash
cd ~ && rm -rf ~/scripts && git clone https://github.com/pmitchell-dev/pi5-scripts.git ~/scripts && cd ~/scripts && ./install.sh --[MODE]
```

### Available Modes:
* `--ntfy`: Configures the server as the **Communication Hub** (Installs speedtest-cli, printer tools, master listener, and Dozzle agent).
* `--webhost`: Configures the server as a **Web Node** (Installs application container stacks and heartbeat watchdog).

### 🔑 Server Identity (`~/.gladstone_mode`)
Upon installation, a hidden file is created at `~/.gladstone_mode`. This file acts as the server's identity card.
* **Sync & Update:** Scripts read this file to determine which services to restart and how to format notifications.
* **Smart Reinstall:** Once the mode is set, you can run `./install.sh` without flags; it remembers its identity automatically.

---

## 📦 Container Services Registry

### Active Docker Containers

| Service / Container | Compose File | Host / Node | Port(s) | Description | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RelayIT Web** (`relayit-web`) | `relayit-compose.yml` | Webhost | 8000 (Internal) | FastAPI Tech Support Ticketing App | **Active (Added)** |
| **RelayIT Database** (`relayit-db`) | `relayit-compose.yml` | Webhost | 5432 (Internal) | PostgreSQL 16 DB for RelayIT | **Active (Added)** |
| **RelayIT Caddy** (`relayit-caddy`) | `relayit-compose.yml` | Webhost | 80 | Caddy Reverse Proxy & HTTP Entrypoint | **Active (Added)** |
| **HomeAsset Web** (`homeasset`) | `homeasset-compose.yml` | Webhost | 8080 | FastAPI Home Asset & Inventory App | **Active** |
| **HomeAsset Database** (`homeasset-db`) | `homeasset-compose.yml` | Webhost | 5432 (Internal) | PostgreSQL 16 DB for HomeAsset | **Active** |
| **JobBoard** (`jobboard`) | `jobboard-compose.yml` | Webhost | 3001 | Next.js Job Aggregator & Dashboard | **Active** |
| **Gemini API** (`gemini-api`) | `gemini-compose.yml` | Webhost | 5050 | Gemini AI Server Endpoint | **Active** |
| **Invidious** (`invidious`) | `invidious-compose.yml` | Webhost | 3000 | Invidious YouTube Privacy Frontend | **Active** |
| **RustDesk ID Server** (`hbbs`) | `rustdesk-compose.yml` | Webhost | 21115 / 21116 | RustDesk Remote Desktop ID Signaling | **Active** |
| **RustDesk Relay** (`hbbr`) | `rustdesk-compose.yml` | Webhost | 21117 | RustDesk Remote Desktop Relay Server | **Active** |
| **Dozzle Log Viewer** (`dozzle`) | `dozzle-compose.yml` | Webhost | 8888 | Centralized Docker Log Dashboard | **Active** |
| **NVR Syslog** (`nvr-syslog`) | `dozzle-compose.yml` | Webhost | 514 (UDP) | ANNKE NVR Camera Syslog Collector | **Active** |
| **Gladstone Logs** (`gladstone-scripts-log`) | `dozzle-compose.yml` | Webhost | N/A | Streamer for Gladstone Script Telemetry | **Active** |
| **Dozzle Agent** (`dozzle-agent`) | `dozzle-agent-compose.yml` | Pi5 Hub | 7007 | Remote Log Agent on Hub | **Active** |

### Removed / Deprecated Containers

| Service / Container | Compose File | Reason for Removal | Status |
| :--- | :--- | :--- | :--- |
| **Hivemind** (`hivemind`) | `hivemind-compose.yml` | Deprecated; functionality migrated to RelayIT and Gemini API stacks | **Removed** |

---

## 🛠️ Core Command Registry

| Command | Alias | Purpose |
| :--- | :--- | :--- |
| `db` | `dashboard` | View system vitals, printer status, and network speeds. |
| `relay` | `relay` | Send formatted ntfy messages to alert channels. |
| `sync` | `sync` | Push local changes to GitHub with mode-aware heartbeat. |
| `update` | `update` | Pull GitHub changes and trigger smart refresh of container stacks. |
| `rebuild` | `rebuild` | Force rebuild and pull latest container stacks from GitHub. |
| `reinstall` | `reinstall` | Run Gladstone bootstrap installer to fix permissions or apply updates. |

---

## 🛡️ System Maintenance

### The 5-Strike Watchdog
`pi_services_manager.sh` runs every 5 minutes. If a persistent service or container fails, the watchdog attempts 4 silent restarts. On the 5th failure, it dispatches an Urgent Priority 5 Alert including error log snippets to ntfy.

### Clean Reset
To reset or clear the Gladstone environment from a machine:
```bash
bash ~/scripts/cleanup_test.sh
```

---

## 📂 Directory Structure
* `~/scripts/`: Core automation logic & docker compose specifications.
* `~/scripts/logs/`: Runtime telemetry & error logs (Excluded from git).
* `~/scripts/backup/`: Daily local ZIP backup rotations (Keeps last 2).
* `~/printer_data/`: Scraped HTML telemetry from Brother printer.