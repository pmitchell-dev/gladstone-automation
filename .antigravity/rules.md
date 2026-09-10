# 🛡️ Gladstone Pi 5 System Rules (Antigravity)
**Core Principle:** This is a production automation environment. All changes must be idempotent and integrated into the Dashboard.

## 📁 File Structure & Permissions
- All shell scripts MUST reside in `/home/gladstone/scripts`.
- Data files (logs, registries) MUST remain in `/home/gladstone/scripts` or `/home/gladstone/printer_data`.
- **Permission Rule:** After creating or modifying any `.sh` file, you MUST trigger `bash install.sh` to enforce `775` permissions.

## 📝 Script Modification SOP
- **Comments:** All scripts must include the Gladstone Header (Purpose, Logic, Logic Flow).
- **Architecture Awareness:** Scripts checking hardware (Temp/IP) must handle both Rhub (ARM) and Laptop (x86) via `vcgencmd` check.
- **Error Handling:** Use `jq -r ".response // empty"` for API calls to prevent null-pointer crashes.

## 📅 Scheduling & Services
- **Crontab:** Never use `crontab -e`. Update the `rebuild.sh` script and execute it to deploy new schedules.
- **Printer Sync:** The Brother Printer (192.168.50.56) is on a 4-hour scrape cycle (0, 8, 12, 16, 20).
- **Watchdog:** The `services_manager.sh` is the master process monitor. Any new persistent service must be added to `services.registry`.

## 📱 Communication (Ntfy)
- **Topic:** `patrick_mitch_hub_x9k2v_alerts`
- **Standard:** Use headers for priority: `-H "Priority: high"` for Printer Jams, `-H "Priority: default"` for Heartbeats.

## 🔄 Deployment Workflow
1. Modify code.
2. Update `SYSTEM_CONTEXT.md` if file list changed.
3. Run `sync` (alias for `sync.sh`) to commit to GitHub.
4. Verify via `db` (alias for `dashboard.sh`).

