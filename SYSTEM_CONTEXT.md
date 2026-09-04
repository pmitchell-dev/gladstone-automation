# 🖥️ Gladstone Master System Context
**Last Updated:** August 15, 2026  
**Architecture:** Hub & Spoke (Communication Hub Model)

---

## 🖥️ Server Roles
* **Hub (RPi5):** The primary entry point. Manages printer logs, network speedtests, and relays commands to other nodes via `--ntfy`.
* **Spoke (Webhost):** Specialized nodes (like the Ubuntu Laptop) that run application stacks (RelayIT, HomeAsset, JobBoard, Gemini API, Invidious, RustDesk, Dozzle) via `--webhost`.

---

## 🚩 Deployment Flags
* `--ntfy`: Installs the full communication suite (speedtest, printer monitoring, master listener, Dozzle agent).
* `--webhost`: Installs web application container stacks and heartbeat watchdog monitoring.

---

## ⏱ Central Hub & Webhost Schedule
* **Printer Scrape:** 4-hour intervals.
* **Network Audit:** 6-hour intervals.
* **Self-Backup:** Daily at midnight via `pi_backup.sh` / `backup_manager.py`.
  * **Webhost Target:** Local path `/mnt/backups/laptopwebhost`
  * **NTFY Hub Target:** Network SMB `//192.168.50.217/Backups/CentralServers` (CIFS mount, credentials `Pi:sambauser`)
* **Watchdog:** 5-minute check with 5-strike retry logic.

---

## 🐳 Docker Containers & Stack Registry

### Active Containers
* **RelayIT Stack** (`relayit-compose.yml`):
  * `relayit-web`: FastAPI Tech Support Ticketing App (Port 8000 internal)
  * `relayit-db`: PostgreSQL 16 DB (Port 5432 internal)
  * `relayit-caddy`: Caddy Reverse Proxy & HTTP Entrypoint (Port 80)
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
  * `dozzle-agent`: Remote Log Agent on Pi5 Hub (Port 7007)
  * `nvr-syslog`: ANNKE NVR Syslog Collector (Port 514 UDP)
* **Simple Login Stack** (`simplelogin-compose.yml`):
  * `simplelogin-app`: Self-Hosted Email Alias Manager UI & API on Pi5 Hub (Port 7777)
  * `simplelogin-db`: PostgreSQL 16 DB (Port 5432 internal)
  * `simplelogin-postfix`: Postfix Mail Server Engine (Port 25)

### Removed / Deprecated Containers
* **Hivemind Stack** (`hivemind-compose.yml`):
  * `hivemind`: Removed from active stack; superseded by RelayIT ticketing and Gemini API integration.

---

## 📊 Centralized Log Viewer
* **Tool:** Dozzle (lightweight Docker log viewer)
* **URL:** http://192.168.50.217:8888
* **Main instance:** Webhost (Ubuntu Laptop) — `dozzle-compose.yml`
* **Agent:** Pi5 Hub — `dozzle-agent-compose.yml` (port 7007)
* **Streams:** All Docker containers on both hosts + Pi5 Gladstone script logs (`/home/pi/scripts/logs/`)
* **NVR (ANNKE):** UDP syslog receiver on port 514 — configure ANNKE Alarm Host to 192.168.50.217
* **Pi5 LAN IP:** 192.168.50.138 | **Webhost LAN IP:** 192.168.50.217

---

## 🧪 Testing & Verification Workflow
* **User-Led Testing:** Testing of changes will be completed by the user after changes are committed and pushed to GitHub.