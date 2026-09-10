#!/bin/bash

# ==========================================================
# GLADSTONE CLOUD SYNC (sync.sh)
# ==========================================================
# PURPOSE: Pushes local script changes to GitHub.
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
LOG_FILE="$SCRIPT_DIR/logs/last_sync.log"

cd "$SCRIPT_DIR" || exit

echo "?? Starting Cloud Sync to GitHub..."

mkdir -p "$SCRIPT_DIR/logs"

git add .
git commit -m "Automated Gladstone Sync: $(date)"
git push origin main

if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M')" > "$LOG_FILE"
    echo "? Sync Successful."
    
    # Updated: Includes Hostname
    curl -d "[$HOSTNAME] Cloud Sync Complete" ntfy.sh/patrick_mitch_hub_x9k2v_alerts
else
    curl -d "[$HOSTNAME] ? Cloud Sync FAILED" ntfy.sh/patrick_mitch_hub_x9k2v_alerts
fi