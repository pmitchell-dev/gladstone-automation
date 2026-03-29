#!/bin/bash
# ==========================================================
# GLADSTONE SERVICE WATCHDOG (v1.9)
# ==========================================================
REGISTRY="/home/pi/scripts/services.registry"
LOG_DIR="/home/pi/scripts/logs"
RETRY_FILE="/tmp/service_retries"
ID_FILE="$HOME/.gladstone_mode"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

MODE=$(cat "$ID_FILE" 2>/dev/null || echo "ntfy")
touch "$RETRY_FILE"

# DOCKER MONITOR (Webhost Only)
if [ "$MODE" == "webhost" ]; then
    if ! docker ps --format '{{.Names}}' | grep -q "^homebox$"; then
        cd /home/pi/homebox && docker compose up -d
        COUNT=$(grep "^homebox:" "$RETRY_FILE" | cut -d: -f2 || echo 0)
        NEW_COUNT=$((COUNT + 1))
        sed -i "/^homebox:/d" "$RETRY_FILE"; echo "homebox:$NEW_COUNT" >> "$RETRY_FILE"
        
        if [ "$NEW_COUNT" -ge 5 ]; then
            curl -H "Priority: 5" -d "[$HOSTNAME] ?? FATAL: Homebox Container Failed." ntfy.sh/$TOPIC
        fi
    else
        sed -i "/^homebox:/d" "$RETRY_FILE"; echo "homebox:0" >> "$RETRY_FILE"
    fi
fi

# REGISTRY MONITOR (Shared)
grep '|' "$REGISTRY" | grep -v '^[[:space:]]*#' | while IFS='|' read -r service port desc; do
    if ! pgrep -fo "$service" > /dev/null; then
        # (Standard restart logic from previous versions)
        nohup /bin/bash /home/pi/scripts/"$service" > "$LOG_DIR/${service%.sh}.log" 2>&1 &
    fi
done