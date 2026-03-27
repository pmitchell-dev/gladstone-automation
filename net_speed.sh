#!/bin/bash

# ==========================================================
# GLADSTONE NETWORK SPEED MONITOR (net_speed.sh)
# ==========================================================
# PURPOSE:
# Runs a background speedtest and logs results to a file.
# This prevents the Dashboard from lagging during load.
#
# LOGIC:
# 1. Executes speedtest-cli in simple mode.
# 2. Captures Download and Upload speeds.
# 3. Writes results to net_speed.log with a timestamp.
# ==========================================================

LOG_FILE="/home/pi/scripts/net_speed.log"

echo "🚀 Running Network Speedtest..."

# Perform the test
RESULTS=$(speedtest-cli --simple)

if [ $? -eq 0 ]; then
    # Save the simple output
    echo "$RESULTS" > "$LOG_FILE"
    # Append the last check time for the dashboard
    echo "Last Checked: $(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE"
    echo "✅ Speedtest logged successfully."
else
    echo "Speedtest Failed" > "$LOG_FILE"
    echo "❌ Speedtest failed. Check internet connection."
fi
