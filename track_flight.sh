#!/bin/bash
# Robust Flight Tracker - Handles casing and null API responses

# 1. Force Uppercase for API compatibility
FLIGHT_IATA=$(echo "${1:-DL1660}" | tr '[:lower:]' '[:upper:]')
DEST_FILTER=$(echo "${2}" | tr '[:lower:]' '[:upper:]')

# --- CONFIGURATION (Ensure these keys are correct!) ---
AIRLABS_KEY="YOUR_AIRLABS_API_KEY"
AVSTACK_KEY="YOUR_AVIATIONSTACK_API_KEY"
NTFY_TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "✈️ Searching for $FLIGHT_IATA ${DEST_FILTER:+to $DEST_FILTER}..."

# --- 2. TRY AIRLABS ---
AIR_RES=$(curl -s "https://airlabs.co/api/v9/flight?flight_iata=$FLIGHT_IATA&api_key=$AIRLABS_KEY")

# Use .response? to avoid crashing on null
if [[ -n "$DEST_FILTER" ]]; then
    DATA=$(echo "$AIR_RES" | jq -r ".response | select(.arr_iata == \"$DEST_FILTER\") // empty")
else
    DATA=$(echo "$AIR_RES" | jq -r ".response // empty")
fi

if [[ -n "$DATA" && "$DATA" != "null" ]]; then
    STATUS=$(echo "$DATA" | jq -r '.status')
    LAT=$(echo "$DATA" | jq -r '.lat')
    LNG=$(echo "$DATA" | jq -r '.lng')
    ALT=$(echo "$DATA" | jq -r '.alt')
    ARR=$(echo "$DATA" | jq -r '.arr_iata')
    SOURCE="Airlabs"
else
    # --- 3. FALLBACK TO AVIATIONSTACK ---
    echo "⚠️ Airlabs result empty. Trying Aviationstack..."
    AV_RES=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$AVSTACK_KEY&flight_iata=$FLIGHT_IATA")
    
    # Use .data[]? to safely skip if .data is null/missing
    if [[ -n "$DEST_FILTER" ]]; then
        DATA=$(echo "$AV_RES" | jq -r ".data[]? | select(.arrival.iata == \"$DEST_FILTER\")" | head -n 1)
    else
        DATA=$(echo "$AV_RES" | jq -r ".data[0]? // empty")
    fi

    if [[ -n "$DATA" && "$DATA" != "null" && "$DATA" != "" ]]; then
        STATUS=$(echo "$DATA" | jq -r '.flight_status')
        LAT=$(echo "$DATA" | jq -r '.live.latitude // "N/A"')
        LNG=$(echo "$DATA" | jq -r '.live.longitude // "N/A"')
        ALT=$(echo "$DATA" | jq -r '.live.altitude // "N/A"')
        ARR=$(echo "$DATA" | jq -r '.arrival.iata')
        SOURCE="Aviationstack"
    else
        echo "❌ No live data found for $FLIGHT_IATA."
        curl -s -d "❌ $FLIGHT_IATA: No live data found on Airlabs or Aviationstack." ntfy.sh/$NTFY_TOPIC
        exit 1
    fi
fi

# --- 4. NOTIFY ---
MSG="✈️ $FLIGHT_IATA to $ARR ($SOURCE)
Status: $STATUS
Alt: ${ALT}ft
Loc: $LAT, $LNG"

curl -s -d "$MSG" ntfy.sh/$NTFY_TOPIC
echo "✅ Notification sent via $SOURCE."
