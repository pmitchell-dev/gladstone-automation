#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="$HOME/scripts"

echo "👂 [$(date)] Listener starting (Smart Mode) on $TOPIC..."

curl -sN ntfy.sh/$TOPIC/json | while read -r line; do
  [[ -z "$line" ]] && continue
  
  # 1. Capture original message and a lowercase version for matching
  RAW_MSG=$(echo "$line" | jq -r '.message // empty' | xargs)
  MSG=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]')

  if [[ -n "$MSG" && "$MSG" != "null" ]]; then
    echo "📥 Received: $RAW_MSG"

    # 2. HELP COMMAND
    if [[ "$MSG" == "help" || "$MSG" == "guide" ]]; then
      echo "❓ Action: Help"
      bash "$SCRIPT_DIR/pi_help.sh" &

    # 3. FLIGHT /STOP
    elif [[ "$MSG" == "flight /stop" ]]; then
      echo "🛑 Action: Stop Trackers"
      pkill -f track_flight.sh
      curl -s -d "🛑 All flight tracking processes stopped." ntfy.sh/$TOPIC

    # 4. FLIGHT /STATUS
    elif [[ "$MSG" == "flight /status" ]]; then
      echo "📊 Action: Status Check"
      if pgrep -f track_flight.sh > /dev/null; then
         curl -s -d "📊 Status: A flight tracker is currently active." ntfy.sh/$TOPIC
      else
         curl -s -d "📊 Status: Idle. No flights being tracked." ntfy.sh/$TOPIC
      fi

    # 5. FLIGHT TRACKING (Matches 'flight dl1660' or 'flight dl1660 to mci')
    elif [[ "$MSG" =~ ^flight\ ([a-z0-9]+)(\ to\ ([a-z]{3}))?$ ]]; then
      FLIGHT_ID="${BASH_REMATCH[1]}"
      DEST_CODE="${BASH_REMATCH[3]}"
      echo "✈️  Action: Tracking $FLIGHT_ID to ${DEST_CODE:-Any}"
      bash "$SCRIPT_DIR/track_flight.sh" "$FLIGHT_ID" "$DEST_CODE" &

    # 6. REBUILD
    elif [[ "$MSG" == "rebuild" ]]; then
      echo "🚀 Action: Rebuild"
      bash "$SCRIPT_DIR/pi_rebuild.sh" &
    
    else
      echo "ℹ️  No command match for: $MSG"
    fi
  fi
done
