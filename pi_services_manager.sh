#!/bin/bash

# ==========================================================
# GLADSTONE SERVICE WATCHDOG (pi_services_manager.sh)
# ==========================================================
# LOGIC:
# 1. Ignores comments in services.registry.
# 2. Tracks retry counts locally in /tmp.
# 3. Only sends ntfy after 5 consecutive failures.
# 4. Includes the last 3 lines of the script's log in the alert.
# ==========================================================

REGISTRY="/home/pi/scripts/services.registry"
LOG_DIR="/home/pi/scripts/logs"
WATCHDOG_LOG="$LOG_DIR/services_manager.log"
RETRY_FILE="/tmp/service_retries"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
MAX_RETRIES=5

# Ensure retry file exists
touch "$RETRY_FILE"

# Loop through registry, ignoring empty lines and comments
grep -v '^#' "$REGISTRY" | grep '[^[:space:]]' | while IFS='|' read -r service port description; do
    
    # Clean whitespace
    service=$(echo "$service" | xargs)

    if ! pgrep -f "$service" > /dev/null; then
        # Increment retry count for this specific service
        CURRENT_COUNT=$(grep "^$service:" "$RETRY_FILE" | cut -d: -f2)
        CURRENT_COUNT=${CURRENT_COUNT:-0}
        NEW_COUNT=$((CURRENT_COUNT + 1))
        
        # Update retry file
        sed -i "/^$service:/d" "$RETRY_FILE"
        echo "$service:$NEW_COUNT" >> "$RETRY_FILE"

        echo "$(date): $service down. Attempt $NEW_COUNT/$MAX_RETRIES" >> "$WATCHDOG_LOG"

        if [ "$NEW_COUNT" -ge "$MAX_RETRIES" ]; then
            # Get last 3 lines of the service's specific log if it exists
            SERVICE_LOG_NAME=$(echo "$service" | sed 's/\.sh/\.log/')
            LOG_SNIPPET="No log found."
            if [ -f "$LOG_DIR/$SERVICE_LOG_NAME" ]; then
                LOG_SNIPPET=$(tail -n 3 "$LOG_DIR/$SERVICE_LOG_NAME" | xargs)
            fi

            # SEND CRITICAL NTFY
            curl -H "Priority: urgent" \
                 -H "Tags: skull,rotating_light" \
                 -d "[$HOSTNAME] ?? FATAL: $service failed $MAX_RETRIES times. 
Log: $LOG_SNIPPET" \
                 ntfy.sh/$TOPIC
            
            # Reset count so it doesn't spam every 5 minutes after reaching max
            sed -i "/^$service:/d" "$RETRY_FILE"
            echo "$service:0" >> "$RETRY_FILE"
        else
            # Attempt the actual restart
            nohup /bin/bash /home/pi/scripts/"$service" > "$LOG_DIR/${service%.sh}.log" 2>&1 &
        fi
    else
        # Service is up, reset the counter to 0
        sed -i "/^$service:/d" "$RETRY_FILE"
        echo "$service:0" >> "$RETRY_FILE"
    fi
done < "$REGISTRY"