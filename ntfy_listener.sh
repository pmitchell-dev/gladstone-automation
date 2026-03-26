#!/bin/bash
# Official Gladstone Pi 5 Listener
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="/home/pi/scripts"

echo "👂 [$(date)] Listener starting..."

curl -sN ntfy.sh/$TOPIC/json | while read -r line; do
    [[ -z "$line" ]] && continue
    RAW_MSG=$(echo "$line" | jq -r '.message // empty' | xargs)
    [[ "$RAW_MSG" =~ ^[❌✅🛠️📊🏥📋✈️] ]] && continue
    MSG=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]')

    if [[ -n "$MSG" ]]; then
        echo "📥 Received: $RAW_MSG"
        
        if [[ "$MSG" == "help" ]]; then
            bash "$SCRIPT_DIR/pi_help.sh" &
        elif [[ "$MSG" == "health" || "$MSG" == "status" ]]; then
            bash "$SCRIPT_DIR/printer_health.sh" &
        elif [[ "$MSG" == "sync" ]]; then
            bash "$SCRIPT_DIR/pi_sync.sh" &
        elif [[ "$MSG" == "cycle" ]]; then
            # We use the function logic here to restart
            curl -s -d "🔄 Restarting listener..." ntfy.sh/$TOPIC
            source /home/pi/.bashrc && cycle &
        elif [[ "$MSG" == "reinstall" || "$MSG" == "rebuild" ]]; then
            bash "$SCRIPT_DIR/pi_rebuild.sh" &
        elif [[ "$MSG" =~ ^flight\ *([a-z]{2})\ *([0-9]+)(\ *to\ *([a-z]{3}))?$ ]]; then
            bash "$SCRIPT_DIR/track_flight.sh" "${BASH_REMATCH[1]}${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}" &
        fi
    fi
done
