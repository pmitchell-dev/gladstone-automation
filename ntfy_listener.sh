#!/bin/bash
# Gladstone Pi 5 Listener - 2026 Stable
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
        elif [[ "$MSG" == "reinstall" || "$MSG" == "rebuild" ]]; then
            bash "$SCRIPT_DIR/pi_rebuild.sh" &
        elif [[ "$MSG" =~ ^flight\ *([a-z]{2})\ *([0-9]+)(\ *to\ *([a-z]{3}))?$ ]]; then
            AIRLINE="${BASH_REMATCH[1]}"
            NUMBER="${BASH_REMATCH[2]}"
            DEST="${BASH_REMATCH[4]}"
            bash "$SCRIPT_DIR/track_flight.sh" "${AIRLINE}${NUMBER}" "$DEST" &
        fi
    fi
done
