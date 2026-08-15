#!/bin/bash

# ==========================================================
# GLADSTONE SYSTEM BACKUP WRAPPER (pi_backup.sh)
# ==========================================================
# PURPOSE:
# Invokes Python Backup Manager (backup_manager.py).
# Handles role-aware backups (Local /mnt/backups/laptopwebhost for Webhost
# and SMB network //192.168.50.217/Backups/CentralServers for NTFY Hub).
# Streams logs to ~/scripts/logs/pi_backup.log.
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/pi_backup.log"

mkdir -p "$LOG_DIR"

if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/backup_manager.py" "$@"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Python3 is not installed. Unable to run Backup Manager." | tee -a "$LOG_FILE"
    exit 1
fi

