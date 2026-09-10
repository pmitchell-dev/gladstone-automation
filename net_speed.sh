#!/bin/bash

# ==========================================================
# GLADSTONE NETWORK SPEED MONITOR (net_speed.sh)
# ==========================================================

LOG_FILE="/home/gladstone/scripts/logs/net_speed.log"
mkdir -p /home/gladstone/scripts/logs

echo "?? Running Network Speedtest..."

RESULTS=$(speedtest-cli --simple)

if [ $? -eq 0 ]; then
    echo "$RESULTS" > "$LOG_FILE"
    echo "Last Checked: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE"
    echo "? Speedtest logged to $LOG_FILE"
else
    echo "Speedtest Failed" > "$LOG_FILE"
fi