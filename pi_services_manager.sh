#!/bin/bash
# Master Services Manager - ONLY monitors "Always-On" scripts

# --- CONFIGURATION ---
# We REMOVED track_flight.sh from here because it's temporary!
SERVICES=("ntfy_listener.sh")
LOG_FILE="/home/pi/services_manager.log"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "--- Check running at $(date) ---" >> $LOG_FILE

for SCRIPT in "${SERVICES[@]}"; do
    if ! pgrep -f "$SCRIPT" > /dev/null; then
        echo "⚠️ ALERT: $SCRIPT was down. Restarting..." >> $LOG_FILE
        /home/pi/$SCRIPT >> /home/pi/ntfy.log 2>&1 &
        curl -s -d "🛠️ Service Manager: $SCRIPT was down and has been restarted." ntfy.sh/$TOPIC
    fi
done
