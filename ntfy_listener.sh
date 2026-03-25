#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="$HOME/scripts"

echo "👂 [$(date)] Listener starting (Commands Enabled) on $TOPIC..."

curl -sN ntfy.sh/$TOPIC/json | while read -r line; do
  [[ -z "$line" ]] && continue
  MESSAGE=$(echo "$line" | jq -r '.message // empty' | xargs)

  if [[ -n "$MESSAGE" && "$MESSAGE" != "null" ]]; then
    echo "📥 Received: $MESSAGE"

    # 1. HELP COMMAND
    if [[ "$MESSAGE" =~ ^[Hh]elp$ ]]; then
      bash "$SCRIPT_DIR/pi_help.sh" &

    # 2. FLIGHT /STOP (Kill active tracking)
    elif [[ "$MESSAGE" == "Flight /stop" ]]; then
      echo "🛑 Killing all flight trackers..."
      pkill -f track_flight.sh
      curl -s -d "🛑 All flight tracking processes stopped." ntfy.sh/$TOPIC

    # 3. FLIGHT /STATUS (Check if running)
    elif [[ "$MESSAGE" == "Flight /status" ]]; then
      if pgrep -f track_flight.sh > /dev/null; then
         curl -s -d "📊 Status: A flight tracker is currently active." ntfy.sh/$TOPIC
      else
         curl -s -d "📊 Status: Idle. No flights being tracked." ntfy.sh/$TOPIC
      fi

    # 4. GENERAL FLIGHT TRACKING
    elif [[ "$MESSAGE" =~ ^[Ff]light\ ([A-Z0-9]+)(\ to\ ([A-Z]{3}))?$ ]]; then
      FLIGHT_ID="${BASH_REMATCH[1]}"
      DEST_CODE="${BASH_REMATCH[3]}"
      bash "$SCRIPT_DIR/track_flight.sh" "$FLIGHT_ID" "$DEST_CODE" &

    # 5. REBUILD
    elif [[ "$MESSAGE" == "rebuild" ]]; then
      bash "$SCRIPT_DIR/pi_rebuild.sh" &
    fi
  fi
done
