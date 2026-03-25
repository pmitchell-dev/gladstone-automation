#!/bin/bash
# Agnostic Listener - Smarter Regex and Logging
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="$HOME/scripts"

echo "👂 [$(date)] Listener starting on $TOPIC..."

# Using --keepalive to prevent the connection from timing out
curl -s --keepalive-time 30 ntfy.sh/$TOPIC/json | while read -r line; do
  # 1. Parse the message
  MESSAGE=$(echo "$line" | jq -r '.message // empty')
  
  if [[ -n "$MESSAGE" ]]; then
    echo "📥 Received: $MESSAGE" # Log it to ~/ntfy.log
    
    # 2. HELP COMMAND (Now matches 'help', 'Help', 'guide', etc anywhere in text)
    if [[ "$MESSAGE" =~ [Hh]elp ]] || [[ "$MESSAGE" =~ [Gg]uide ]]; then
      echo "❓ Running help script..."
      bash "$SCRIPT_DIR/pi_help.sh" &
    fi

    # 3. FLIGHT COMMAND
    if [[ "$MESSAGE" =~ [Ff]light\ ([A-Z0-9]+)(\ to\ ([A-Z]{3}))? ]]; then
      FLIGHT_ID="${BASH_REMATCH[1]}"
      DEST_CODE="${BASH_REMATCH[3]}"
      echo "✈️  Tracking flight: $FLIGHT_ID to ${DEST_CODE:-Any}"
      bash "$SCRIPT_DIR/track_flight.sh" "$FLIGHT_ID" "$DEST_CODE" &
    fi

    # 4. REBUILD COMMAND
    if [[ "$MESSAGE" == "rebuild" ]]; then
      echo "🚀 Starting system rebuild..."
      bash "$SCRIPT_DIR/pi_rebuild.sh" &
    fi
  fi
done
