#!/bin/bash
# Dual-Source Flight Tracker: Airlabs -> Aviationstack Fallback

# --- CONFIGURATION ---
FLIGHT_IATA="${1:-DL1660}" # Change to your flight number
AIRLABS_KEY="4dc4b2db-5edb-432d-b858-50b9aa4e3afd"
AVSTACK_KEY="a76fc6fbed55a5d632bf7854fb4db2b9"
NTFY_TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "✈️ Checking flight $FLIGHT_IATA..."

# --- 1. TRY AIRLABS (PRIMARY) ---
echo "📡 Attempting Airlabs..."
AIR_RES=$(curl -s "https://airlabs.co/api/v9/flight?flight_iata=$FLIGHT_IATA&api_key=$AIRLABS_KEY")
STATUS=$(echo $AIR_RES | jq -r '.response.status // empty')

if [[ -n "$STATUS" && "$STATUS" != "null" ]]; then
    LAT=$(echo $AIR_RES | jq -r '.response.lat')
    LNG=$(echo $AIR_RES | jq -r '.response.lng')
    ALT=$(echo $AIR_RES | jq -r '.response.alt')
    SOURCE="Airlabs"
else
    # --- 2. FALLBACK TO AVIATIONSTACK ---
    echo "⚠️ Airlabs failed. Attempting Aviationstack fallback..."
    AV_RES=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$AVSTACK_KEY&flight_iata=$FLIGHT_IATA")
    STATUS=$(echo $AV_RES | jq -r '.data[0].flight_status // empty')
    
    if [[ -n "$STATUS" && "$STATUS" != "null" ]]; then
        LAT=$(echo $AV_RES | jq -r '.data[0].live.latitude // "N/A"')
        LNG=$(echo $AV_RES | jq -r '.data[0].live.longitude // "N/A"')
        ALT=$(echo $AV_RES | jq -r '.data[0].live.altitude // "N/A"')
        SOURCE="Aviationstack"
    else
        echo "❌ Both APIs failed to find flight $FLIGHT_IATA."
        exit 1
    fi
fi

# --- 3. SEND NOTIFICATION ---
MSG="✈️ $FLIGHT_IATA Update ($SOURCE)
Status: $STATUS
Alt: ${ALT}ft
Loc: $LAT, $LNG"

curl -d "$MSG" ntfy.sh/$NTFY_TOPIC
echo "✅ Status: $STATUS via $SOURCE. Notification sent."
