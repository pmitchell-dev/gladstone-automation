#!/bin/bash

# ==========================================================
# GLADSTONE SERVICE WATCHDOG (pi_services_manager.sh)
# ==========================================================

REGISTRY="/home/pi/scripts/services.registry"
LOG="/home/pi/scripts/logs/services_manager.log"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

while IFS='|' read -r service port description; do
    if ! pgrep -f "$service" > /dev/null; then
        echo "$(date): $service down. Restarting..." >> "$LOG"
        
        # Updated: Includes Hostname
        curl -H "Priority: high" \
             -d "[$HOSTNAME] ?? Service Down: $service. Attempting restart..." \
             ntfy.sh/$TOPIC
             
        nohup /bin/bash /home/pi/scripts/"$service" > /home/pi/scripts/logs/ntfy.log 2>&1 &
    fi
done < "$REGISTRY"