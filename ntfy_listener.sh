#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "👂 Listener active... waiting for 'Flight [ID] to [DEST]'"

curl -s ntfy.sh/$TOPIC/json | while read line; do
  MESSAGE=$(echo "$line" | jq -r '.message // empty')
  
  # Regex: Matches "Flight DL1660" OR "Flight DL1660 to MSP"
  if [[ $MESSAGE =~ [Ff]light\ ([A-Z0-9]+)(\ to\ ([A-Z]{3}))? ]]; then
    FLIGHT_ID="${BASH_REMATCH[1]}"
    DEST_CODE="${BASH_REMATCH[3]}"
    
    echo "✈️ Request: $FLIGHT_ID | Dest: ${DEST_CODE:-Any}"
    bash $HOME/scripts/track_flight.sh "$FLIGHT_ID" "$DEST_CODE" &
  fi

  if [[ "$MESSAGE" == "rebuild" ]]; then
    bash $HOME/scripts/pi_rebuild.sh &
  fi
done
