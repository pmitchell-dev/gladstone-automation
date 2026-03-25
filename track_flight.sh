#!/bin/bash
# Dual-Source Flight Tracker with Destination Filtering

FLIGHT_IATA="${1:-DL1660}"
DEST_FILTER=$(echo "$2" | tr '[:lower:]' '[:upper:]') # Optional destination
AIRLABS_KEY="YOUR_AIRLABS_API_KEY"
AVSTACK_KEY="YOUR_AVIATIONSTACK_API_KEY"
NTFY_TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "✈️ Searching for $FLIGHT_IATA ${DEST_FILTER:+to $DEST_FILTER}..."

# --- 1. TRY AIRLABS ---
AIR_RES=$(curl -s "https://airlabs.co/api/v9/flight?flight_iata=$FLIGHT_IATA&api_key=$AIRLABS_KEY")

# Filter Airlabs result by destination if provided
if [[ -n "$DEST_FILTER" ]]; then
    DATA=$(echo "$AIR_RES" | jq -r ".response | select(.arr_iata == \"$DEST_FILTER\")")
else
    DATA=$(echo "$AIR_RES" | jq -r ".response")
fi

if [[ -n "$DATA" && "$DATA" != "null" ]]; then
    STATUS=$(echo "$DATA" | jq -r '.status')
    LAT=$(echo "$DATA" | jq -r '.lat')
    LNG=$(echo "$DATA" | jq -r '.lng')
    ALT=$(echo "$DATA" | jq -r '.alt')
    ARR=$(echo "$DATA" | jq -r '.arr_iata')
    SOURCE="Airlabs"
else
    # --- 2. FALLBACK TO AVIATIONSTACK ---
    AV_RES=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$AVSTACK_KEY&flight_iata=$FLIGHT_IATA")
    
    if [[ -n "$DEST_FILTER" ]]; then
        DATA=$(echo "$AV_RES" | jq -r ".data[] | select(.arrival.iata == \"$DEST_FILTER\") | first")
    else
        DATA=$(echo "$AV_RES" | jq -r ".data[0]")
    fi

    if [[ -n "$DATA" && "$DATA" != "null" ]]; then
        STATUS=$(echo "$DATA" | jq -r '.flight_status')
        LAT=$(echo "$DATA" | jq -r '.live.latitude // "N/A"')
        LNG=$(echo "$DATA" | jq -r '.live.longitude // "N/A"')
        ALT=$(echo "$DATA" | jq -r '.live.altitude // "N/A"')
        ARR=$(echo "$DATA" | jq -r '.arrival.iata')
        SOURCE="Aviationstack"
    else
        echo "❌ No flight found for $FLIGHT_IATA $DEST_FILTER"
        exit 1
    fi
fi

# --- 3. NOTIFY ---
MSG="✈️ $FLIGHT_IATA to $ARR ($SOURCE)
Status: $STATUS
Alt: ${ALT}ft
Loc: $LAT, $LNG"

curl -d "$MSG" ntfy.sh/$NTFY_TOPIC
