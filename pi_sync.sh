#!/bin/bash

# ==========================================================
# GLADSTONE CLOUD SYNC (pi_sync.sh)
# ==========================================================
# PURPOSE:
# Pushes local script changes to GitHub and logs a heartbeat.
#
# LOGIC:
# 1. Navigates to the scripts directory.
# 2. Stages, commits, and pushes to origin main.
# 3. Writes the success timestamp to the local logs folder.
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
LOG_FILE="$SCRIPT_DIR/logs/last_sync.log"

cd $SCRIPT_DIR || exit

echo "?? Starting Cloud Sync to GitHub..."

# Ensure the logs directory exists before writing
mkdir -p "$SCRIPT_DIR/logs"

# Git Operations
git add .
git commit -m "Automated Gladstone Sync: $(date)"
git push origin main

if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M')" > "$LOG_FILE"
    echo "? Sync Successful. Timestamp updated in $LOG_FILE"
    
    # Optional: Send ntfy heartbeat (using the _vitals channel if you choose)
    curl -d "Gladstone Sync Complete: $(hostname)" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
else
    echo "? Sync Failed. Check GitHub credentials or connection."
fi