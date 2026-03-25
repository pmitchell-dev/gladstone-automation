#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="$HOME/scripts"

echo "👂 [$(date)] Listener starting (Filtered) on $TOPIC..."

curl -sN ntfy.sh/$TOPIC/json | while read -r line; do
  [[ -z "$line" ]] && continue
  
  # 1. Capture message and trim it
  RAW_MSG=$(echo "$line" | jq -r '.message // empty' | xargs)
  
  # 2. BOT FILTER: Ignore any message starting with an emoji or "Check"
  [[ "$RAW_MSG" =~ ^[❌✅🛠️📊] ]] && continue
  [[ "$RAW_MSG" == *"No live data"* ]] && continue

  MSG=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]')

  if [[ -n "$MSG" ]]; then
    echo "📥 Received: $RAW_MSG"

    if [[ "$MSG" == "help" ]]; then
      bash "$SCRIPT_DIR/pi_help.sh" &

    # Matches "flight dl1660", "flight dl 1660", "flight wn102 to mci"
    elif [[ "$MSG" =~ ^flight\ *([a-z]{2})\ *([0-9]+)(\ *to\ *([a-z]{3}))?$ ]]; then
      AIRLINE="${BASH_REMATCH[1]}"
      NUMBER="${BASH_REMATCH[2]}"
      DEST="${BASH_REMATCH[4]}"
      FLIGHT_ID="${AIRLINE}${NUMBER}"
      bash "$SCRIPT_DIR/track_flight.sh" "$FLIGHT_ID" "$DEST" &

    elif [[ "$MSG" == "rebuild" ]]; then
      bash "$SCRIPT_DIR/pi_rebuild.sh" &
    fi
  fi
done
