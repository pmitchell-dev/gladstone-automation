# 🖥️ Gladstone Master System Context
**Last Updated:** September 7, 2026  
**Architecture:** Hub & Spoke (Communication Hub Model)

---

## 🖥️ Server Roles
* **Hub (Rhub):** The primary entry point. Manages printer logs, network speedtests, Google Drive media backups, and relays commands to other nodes via `--ntfy`.
* **Spoke (Webhost):** Specialized nodes (like the Ubuntu Laptop) that run application stacks (HomeAsset, JobBoard, Gemini API, RustDesk, Dozzle) via `--webhost`.

---

## 🚩 Deployment Flags
* `--ntfy`: Installs the full communication suite (speedtest, printer monitoring, master listener, Dozzle agent).
* `--webhost`: Installs web application container stacks (HomeAsset, JobBoard, Gemini API, RustDesk, Dozzle, Immich), Google Drive rclone photo sync, and heartbeat watchdog monitoring.

---

## ⏱ Central Hub & Webhost Schedule
* **Printer Scrape:** 4-hour intervals.
* **Network Audit:** 6-hour intervals.
* **Self-Backup:** Daily at midnight via `backup.sh` / `backup_manager.py`.
  * **Webhost Target:** Local path `/mnt/backups/laptopwebhost`
  * **NTFY Hub Target:** Network SMB `//192.168.50.217/Backups/CentralServers` (CIFS mount, credentials `gladstone:sambauser`)
* **Google Drive Photo Sync:** Daily at 02:00 AM via `rclone_gdrive_photos.sh` (Configured dynamically via `~/.config/rclone/rclone_photos.env`)
* **Watchdog:** 5-minute check with 5-strike retry logic.

---

## 🐳 Docker Containers & Stack Registry

### Active Containers
* **HomeAsset Stack** (`homeasset-compose.yml`):
  * `homeasset`: FastAPI Home Asset & Inventory App (Port 8080)
  * `homeasset-db`: PostgreSQL 16 DB (Port 5432 internal)
* **JobBoard Stack** (`jobboard-compose.yml`):
  * `jobboard`: Next.js Job Aggregator & Dashboard (Port 3001)
* **Gemini API Stack** (`gemini-compose.yml`):
  * `gemini-api`: Python Gemini AI Endpoint (Port 5050)
* **RustDesk Stack** (`rustdesk-compose.yml`):
  * `hbbs`: RustDesk ID Signaling Server (Port 21115 / 21116)
  * `hbbr`: RustDesk Relay Server (Port 21117)
* **Dozzle Log Viewer Stack** (`dozzle-compose.yml` & `dozzle-agent-compose.yml`):
  * `dozzle`: Centralized Log Dashboard on Webhost (Port 8888)
  * `dozzle-agent`: Remote Log Agent on hub Hub (Port 7007)
  * `nvr-syslog`: ANNKE NVR Syslog Collector (Port 514 UDP)
* **Simple Login Stack** (`simplelogin-compose.yml`):
  * `simplelogin-app`: Self-Hosted Email Alias Manager UI & API on hub Hub (`http://simplelogin.localrepo.net:7777` / domain: `localrepo.net`)
  * `simplelogin-db`: PostgreSQL 16 DB (Port 5432 internal)
  * `simplelogin-postfix`: Postfix Mail Server Engine (Port 25)
* **Immich Photo & Video Stack** (`immich-compose.yml`):
  * `immich_server`: Immich Web UI & API Backend on Webhost (`http://192.168.50.217:2283`)
  * `immich_postgres`: PostgreSQL Vector DB (`pgvector`)
  * `immich_redis`: Valkey Cache & Queue Broker
  * *(Machine Learning: Remote node via `IMMICH_MACHINE_LEARNING_URL=http://192.168.50.138:3003`)*

### Removed / Deprecated Containers
* **Hivemind Stack** (`hivemind-compose.yml`):
  * `hivemind`: Removed from active stack; superseded by Gemini API integration.

---

## 📊 Centralized Log Viewer
* **Tool:** Dozzle (lightweight Docker log viewer)
* **URL:** http://192.168.50.217:8888
* **Main instance:** Webhost (Ubuntu Laptop) — `dozzle-compose.yml`
* **Agent:** hub Hub — `dozzle-agent-compose.yml` (port 7007)
* **Streams:** All Docker containers on both hosts + hub Gladstone script logs (`/home/gladstone/scripts/logs/`)
* **NVR (ANNKE):** UDP syslog receiver on port 514 — configure ANNKE Alarm Host to 192.168.50.217
* **hub LAN IP:** 192.168.50.138 | **Webhost LAN IP:** 192.168.50.217

---

## 🧪 Testing & Verification Workflow
* **User-Led Testing:** Testing of changes will be completed by the user after changes are committed and pushed to GitHub.