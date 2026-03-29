#!/bin/bash
# ==========================================================
# GLADSTONE SERVICE WATCHDOG (v1.5 - Parent-Only/Level 5)
# ==========================================================
REGISTRY="/home/pi/scripts/services.registry"
LOG_DIR="/home/pi/scripts/logs"
RETRY_FILE="/tmp/service_retries"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
MAX_RETRIES=5

# Ensure state file exists
touch "$RETRY_FILE"

# 1. Filter Registry: Only lines with | and NOT starting with #
grep '|' "$REGISTRY" | grep -v '^[[:space:]]*#' | while IFS='|' read -r service port desc; do
    
    # Clean whitespace
    service=$(echo "$service" | xargs)
    [ -z "$service" ] && continue

    # 2. Check for Parent Process (-f = full command, -o = oldest/parent only)
    if ! pgrep -fo "$service" > /dev/null; then
        # Increment Retry Count
        COUNT=$(grep "^$service:" "$RETRY_FILE" | cut -d: -f2)
        COUNT=${COUNT:-0}
        NEW_COUNT=$((COUNT + 1))
        
        sed -i "/^$service:/d" "$RETRY_FILE"
        echo "$service:$NEW_COUNT" >> "$RETRY_FILE"

        # 3. Handle Escalation
        if [ "$NEW_COUNT" -ge "$MAX_RETRIES" ]; then
            # Extract log snippet
            LOG_SNIP=$(tail -n 3 "$LOG_DIR/${service%.sh}.log" 2>/dev/null | xargs)
            
            # SEND LEVEL 5 (URGENT) NTFY
            curl -H "Priority: 5" \
                 -H "Tags: skull,rotating_light" \
                 -H "Title: ?? SERVICE FATAL ($HOSTNAME)" \
                 -d "$service failed $MAX_RETRIES times. 
Log: ${LOG_SNIP:-No log found.}" \
                 ntfy.sh/$TOPIC
            
            # Reset to stop the 5-minute spam loop
            sed -i "/^$service:/d" "$RETRY_FILE"
            echo "$service:0" >> "$RETRY_FILE"
        else
            # Attempt Background Restart
            nohup /bin/bash /home/pi/scripts/"$service" > "$LOG_DIR/${service%.sh}.log" 2>&1 &
            echo "$(date): Attempted restart of $service ($NEW_COUNT/$MAX_RETRIES)" >> "$LOG_DIR/services_manager.log"
        fi
    else
        # Service is healthy, ensure counter is zero
        if grep -q "^$service:" "$RETRY_FILE"; then
            sed -i "/^$service:/d" "$RETRY_FILE"
            echo "$service:0" >> "$RETRY_FILE"
        fi
    fi
done