# ?? Gladstone Master System Context
**Last Updated:** March 28, 2026  
**Architecture:** Hub & Spoke (Communication Hub Model)

---

## ??? Server Roles
* **Hub (RPi5):** The primary entry point. Manages printer logs, network speedtests, and relays commands to other nodes via `--ntfy`.
* **Spoke (Webhost):** Specialized nodes (like the Ubuntu Laptop) that run specific web services via `--webhost`.

---

## ??? Deployment Flags
* `--ntfy`: Installs the full communication suite (speedtest, printer monitoring, master listener).
* `--webhost`: Installs a minimal footprint for web services and basic heartbeat monitoring.

---

## ?? Central Hub Schedule
* **Printer Scrape:** 4-hour intervals.
* **Network Audit:** 6-hour intervals.
* **Self-Backup:** Daily at midnight.
* **Watchdog:** 5-minute check with 5-strike retry logic.