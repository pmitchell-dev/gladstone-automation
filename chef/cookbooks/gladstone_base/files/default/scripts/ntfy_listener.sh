#!/bin/bash

# ==========================================================
# OFFICIAL GLADSTONE PI 5 COMMAND LISTENER
# ==========================================================
# PURPOSE:
# This script maintains a persistent connection to a private
# ntfy.sh topic to act as a remote command-and-control hub.
#
# HOW IT WORKS:
# 1. Streams JSON data from ntfy.sh using a continuous curl.
# 2. Filters out system status emojis to prevent loops.
# 3. Normalizes all incoming text to lowercase for matching.
# 4. Executes local bash scripts from the /scripts directory
#    based on keyword triggers (help, health, sync, etc.).
# 5. Supports regex-based flight tracking via track_flight.sh.
#
# RELIABILITY:
# Commands are launched in the background (&) to ensure the
# listener remains responsive to subsequent messages.
# ==========================================================

TOPIC="patrick_mitch_pi5_x9k2v_alerts"
LISTEN_TOPICS="patrick_mitch_pi5_x9k2v_alerts,patrick_mitch_pi5_x9k2v_actions"
SCRIPT_DIR="/home/gladstone/scripts"

echo "👂 [$(date)] Listener starting..."

while true; do
    echo "🔌 [$(date)] Connecting to ntfy stream..."

    curl -sS -N --max-time 0 "https://ntfy.sh/$LISTEN_TOPICS/json" | while read -r line; do
        [[ -z "$line" ]] && continue
        RAW_MSG=$(echo "$line" | jq -r '.message // empty' | xargs)
        [[ "$RAW_MSG" =~ ^[❌✅🛠️📊🏥📋✈️] ]] && continue
        MSG=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]')

        if [[ -n "$MSG" ]]; then
            echo "📥 Received: $RAW_MSG"

            if [[ "$MSG" == "help" ]]; then
                bash "$SCRIPT_DIR/help.sh" &
            elif [[ "$MSG" == "health" || "$MSG" == "status" ]]; then
                bash "$SCRIPT_DIR/printer_health.sh" &
            elif [[ "$MSG" == "sync" ]]; then
                bash "$SCRIPT_DIR/sync.sh" &
            elif [[ "$MSG" == "cycle" ]]; then
                # We use the function logic here to restart
                curl -s -d "🔄 Restarting listener..." ntfy.sh/$TOPIC
                source /home/gladstone/.bashrc && cycle &
            elif [[ "$MSG" == "reinstall" || "$MSG" == "rebuild" ]]; then
                bash "$SCRIPT_DIR/rebuild.sh" &
            elif [[ "$MSG" =~ ^flight\ *([a-z]{2})\ *([0-9]+)(\ *to\ *([a-z]{3}))?$ ]]; then
                bash "$SCRIPT_DIR/track_flight.sh" "${BASH_REMATCH[1]}${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}" &
            elif [[ "$MSG" == "mute_watchdog" ]]; then
                date -d "tomorrow 08:00" +%s > /tmp/gladstone_ntfy_mute
                curl -s -H "Priority: 3" -d "🔕 Watchdog alerts muted until 8 AM tomorrow." ntfy.sh/$TOPIC &
            fi
        fi
    done

    echo "🔄 [$(date)] Stream disconnected. Reconnecting in 10s..."
    sleep 10
done
