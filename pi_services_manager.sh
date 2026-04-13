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
    if ! docker ps --format '{{.Names}}' | grep -q "^homeasset$"; then
        cd /home/pi/homeasset && docker compose up -d
        COUNT=$(grep "^homeasset:" "$RETRY_FILE" | cut -d: -f2 || echo 0)
        NEW_COUNT=$((COUNT + 1))
        sed -i "/^homeasset:/d" "$RETRY_FILE"; echo "homeasset:$NEW_COUNT" >> "$RETRY_FILE"
        
        if [ "$NEW_COUNT" -ge 5 ]; then
            NOW=$(date +%s)
            MUTE_UNTIL=$(cat /tmp/gladstone_ntfy_mute 2>/dev/null || echo 0)
            if [[ "$MUTE_UNTIL" =~ ^[0-9]+$ ]] && [ "$NOW" -ge "$MUTE_UNTIL" ]; then
                curl -H "Priority: 5" \
                     -H "Actions: http, Mute rest of the day, https://ntfy.sh/patrick_mitch_pi5_x9k2v_actions, method=POST, body=mute_watchdog" \
                     -d "[$HOSTNAME] ?? FATAL: HomeAsset Container Failed." ntfy.sh/$TOPIC
            fi
        fi
    else
        sed -i "/^homeasset:/d" "$RETRY_FILE"; echo "homeasset:0" >> "$RETRY_FILE"
    fi
fi

# REGISTRY MONITOR (Shared)
grep '|' "$REGISTRY" | grep -v '^[[:space:]]*#' | while IFS='|' read -r service port desc; do
    if ! pgrep -fo "$service" > /dev/null; then
        # (Standard restart logic from previous versions)
        nohup /bin/bash /home/pi/scripts/"$service" > "$LOG_DIR/${service%.sh}.log" 2>&1 &
    fi
done