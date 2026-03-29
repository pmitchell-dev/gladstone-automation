#!/bin/bash
# ==========================================================
# GLADSTONE SERVICE WATCHDOG (v1.8 - Docker/Webhost Mode)
# ==========================================================
REGISTRY="/home/pi/scripts/services.registry"
LOG_DIR="/home/pi/scripts/logs"
RETRY_FILE="/tmp/service_retries"
ID_FILE="$HOME/.gladstone_mode"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
MAX_RETRIES=5

MODE=$(cat "$ID_FILE" 2>/dev/null || echo "ntfy")
touch "$RETRY_FILE"

# --- 1. MONITOR DOCKER (Webhost Mode Only) ---
if [ "$MODE" == "webhost" ]; then
    # Check if 'homebox' container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^homebox$"; then
        echo "?? Homebox container is DOWN. Attempting restart..."
        cd /home/pi/homebox && docker compose up -d
        
        # Log and Alert if failure persists
        COUNT=$(grep "^homebox:" "$RETRY_FILE" | cut -d: -f2 || echo 0)
        NEW_COUNT=$((COUNT + 1))
        sed -i "/^homebox:/d" "$RETRY_FILE"
        echo "homebox:$NEW_COUNT" >> "$RETRY_FILE"
        
        if [ "$NEW_COUNT" -ge "$MAX_RETRIES" ]; then
            curl -H "Priority: 5" -H "Tags: skull" -d "[$HOSTNAME] ?? FATAL: Homebox Docker failed $MAX_RETRIES times." ntfy.sh/$TOPIC
        fi
    else
        sed -i "/^homebox:/d" "$RETRY_FILE"
        echo "homebox:0" >> "$RETRY_FILE"
    fi
fi

# --- 2. MONITOR REGISTRY SCRIPTS (All Modes) ---
grep '|' "$REGISTRY" | grep -v '^[[:space:]]*#' | while IFS='|' read -r service port desc; do
    service=$(echo "$service" | xargs)
    [ -z "$service" ] && continue

    if ! pgrep -fo "$service" > /dev/null; then
        COUNT=$(grep "^$service:" "$RETRY_FILE" | cut -d: -f2 || echo 0)
        NEW_COUNT=$((COUNT + 1))
        
        sed -i "/^$service:/d" "$RETRY_FILE"
        echo "$service:$NEW_COUNT" >> "$RETRY_FILE"

        if [ "$NEW_COUNT" -ge "$MAX_RETRIES" ]; then
            LOG_SNIP=$(tail -n 3 "$LOG_DIR/${service%.sh}.log" 2>/dev/null | xargs)
            curl -H "Priority: 5" -H "Tags: skull" -d "[$HOSTNAME] ?? FATAL: $service failed $MAX_RETRIES times." ntfy.sh/$TOPIC
            sed -i "/^$service:/d" "$RETRY_FILE"; echo "$service:0" >> "$RETRY_FILE"
        else
            nohup /bin/bash /home/pi/scripts/"$service" > "$LOG_DIR/${service%.sh}.log" 2>&1 &
        fi
    else
        sed -i "/^$service:/d" "$RETRY_FILE"; echo "$service:0" >> "$RETRY_FILE"
    fi
done