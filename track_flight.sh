#!/bin/bash
API_KEY="a76fc6fbed55a5d632bf7854fb4db2b9"
FLIGHT_ID=$(echo "$1" | tr '[:lower:]' '[:upper:]' | xargs)
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

if [ -z "$FLIGHT_ID" ]; then exit 1; fi

check_flight() {
    # Query API for the flight
    RESPONSE=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$API_KEY&flight_iata=$FLIGHT_ID")
    
    # Extract data using jq
    STATUS=$(echo "$RESPONSE" | jq -r '.data[0].flight_status // "unknown"')
    DEP=$(echo "$RESPONSE" | jq -r '.data[0].departure.iata // "???"')
    ARR=$(echo "$RESPONSE" | jq -r '.data[0].arrival.iata // "???"')
    
    # Get best available arrival time (Actual > Estimated > Scheduled)
    ETA=$(echo "$RESPONSE" | jq -r '.data[0].arrival.actual // .data[0].arrival.estimated // .data[0].arrival.scheduled // "N/A"' | grep -oE '[0-9]{2}:[0-9]{2}' | head -1)

    MSG="✈️ $FLIGHT_ID Update
Status: ${STATUS^}
Route: $DEP ➔ $ARR
Arr Time: $ETA"

    curl -s -d "$MSG" ntfy.sh/$TOPIC > /dev/null
    echo "$STATUS"
}

# Start tracking
curl -s -d "📡 Tracking $FLIGHT_ID every 30m. Send 'stop $FLIGHT_ID' to end." ntfy.sh/$TOPIC > /dev/null

while true; do
    CURRENT_STATUS=$(check_flight)
    
    # Auto-stop if landed or cancelled
    if [[ "$CURRENT_STATUS" == "landed" || "$CURRENT_STATUS" == "cancelled" ]]; then
        curl -s -d "🏁 $FLIGHT_ID has $CURRENT_STATUS. Tracking finished." ntfy.sh/$TOPIC > /dev/null
        break
    fi
    
    sleep 1800 # 30 mins
done
