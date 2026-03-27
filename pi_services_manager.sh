#!/bin/bash

# ==========================================================
# PI 5 MASTER SERVICES WATCHDOG (PROCESS MONITOR)
# ==========================================================
# 1. Monitors scripts in /home/pi/scripts/
# 2. Restarts them if they crash or stop.
# 3. Sends recovery alerts to the PUBLIC ntfy.sh cloud.
# ==========================================================

SERVICES=("ntfy_listener.sh")
LOG_FILE="/home/pi/services_manager.log"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "--- Check running at $(date) ---" >> $LOG_FILE

for SCRIPT in "${SERVICES[@]}"; do
    # Check if the script is running
    if ! pgrep -f "$SCRIPT" > /dev/null; then
        echo "⚠️ ALERT: $SCRIPT was down. Restarting..." >> $LOG_FILE
        
        # Correct path to the scripts folder
        /home/pi/scripts/$SCRIPT >> /home/pi/ntfy.log 2>&1 &
        
        # Send alert to the PUBLIC cloud so you get it on your phone
        curl -s -d "🛠️ Service Manager: $SCRIPT was down and has been restarted." ntfy.sh/$TOPIC
    fi
done
