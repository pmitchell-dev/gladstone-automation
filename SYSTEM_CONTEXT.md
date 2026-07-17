# 🖥️ Gladstone Master System Context
**Last Updated:** July 17, 2026  
**Architecture:** Hub & Spoke (Communication Hub Model)

---

## 🖥️ Server Roles
* **Hub (RPi5):** The primary entry point. Manages printer logs, network speedtests, and relays commands to other nodes via `--ntfy`.
* **Spoke (Webhost):** Specialized nodes (like the Ubuntu Laptop) that run specific web services (Invidious, RustDesk, JobBoard, Open WebUI, LiteLLM) via `--webhost`.

---

## ??? Deployment Flags
* `--ntfy`: Installs the full communication suite (speedtest, printer monitoring, master listener).
* `--webhost`: Installs a minimal footprint for web services and basic heartbeat monitoring.

---

## ⏱ Central Hub Schedule
* **Printer Scrape:** 4-hour intervals.
* **Network Audit:** 6-hour intervals.
* **Self-Backup:** Daily at midnight.
* **Watchdog:** 5-minute check with 5-strike retry logic.

---

## 📊 Centralized Log Viewer
* **Tool:** Dozzle (lightweight Docker log viewer)
* **URL:** http://192.168.50.217:8888
* **Main instance:** Webhost (Ubuntu Laptop) — `dozzle-compose.yml`
* **Agent:** Pi5 Hub — `dozzle-agent-compose.yml` (port 7007)
* **Streams:** All Docker containers on both hosts + Pi5 Gladstone script logs (`/home/pi/scripts/logs/`)
* **NVR (ANNKE):** UDP syslog receiver on port 514 — configure ANNKE Alarm Host to 192.168.50.217
* **Pi5 LAN IP:** 192.168.50.138 | **Webhost LAN IP:** 192.168.50.217