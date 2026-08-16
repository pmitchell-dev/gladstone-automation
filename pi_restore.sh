#!/bin/bash

# ==========================================================
# GLADSTONE SYSTEM RESTORE WRAPPER (pi_restore.sh)
# ==========================================================
# PURPOSE:
# Invokes Python Restore Manager (restore_manager.py).
# Provides interactive backup selection, SHA256 verification,
# automated container teardown, and data restoration.
# Streams logs to ~/scripts/logs/pi_restore.log.
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/pi_restore.log"

mkdir -p "$LOG_DIR"

if command -v python3 >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/restore_manager.py" "$@"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Python3 is not installed. Unable to run Restore Manager." | tee -a "$LOG_FILE"
    exit 1
fi
