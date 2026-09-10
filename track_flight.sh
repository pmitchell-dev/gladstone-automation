#!/bin/bash

# ==========================================================
# GLADSTONE FLIGHT TRACKER (RADAR + SCHEDULE FALLBACK)
# ==========================================================
# PURPOSE:
# Tracks a specific flight by IATA code (e.g., DL1660).
# Priority 1: Live Radar (Airlabs) for GPS/Altitude.
# Priority 2: Schedule (Aviationstack) if flight hasn't taken off.
# ==========================================================

# --- CONFIGURATION & INPUT ---
# tr converts input to uppercase so 'dl1660' becomes 'DL1660'
FLIGHT_IATA=$(echo "${1:-DL1660}" | tr '[:lower:]' '[:upper:]')
DEST_FILTER=$(echo "${2}" | tr '[:lower:]' '[:upper:]')

# API KEYS (Note: Aviationstack key still needs to be inserted below)
AIRLABS_KEY="4dc4b2db-5edb-432d-b858-50b9aa4e3afd"
AVSTACK_KEY="YOUR_AVIATIONSTACK_API_KEY"
NTFY_TOPIC="patrick_mitch_hub_x9k2v_alerts"

echo "✈️ Querying $FLIGHT_IATA..."

# --- 1. STAGE ONE: AIRLABS (LIVE RADAR) ---
# This API provides real-time GPS coordinates and altitude.
AIR_RES=$(curl -s "https://airlabs.co/api/v9/flight?flight_iata=$FLIGHT_IATA&api_key=$AIRLABS_KEY")
DATA=$(echo "$AIR_RES" | jq -r ".response // empty")

if [[ -n "$DATA" && "$DATA" != "null" ]]; then
    # Parse GPS and Flight Vitals
    STATUS=$(echo "$DATA" | jq -r '.status')
    LAT=$(echo "$DATA" | jq -r '.lat')
    LNG=$(echo "$DATA" | jq -r '.lng')
    ALT=$(echo "$DATA" | jq -r '.alt')
    
    MSG="✈️ $FLIGHT_IATA (Live Radar)
Status: $STATUS
Alt: ${ALT}ft | Loc: $LAT, $LNG"

else
    # --- 2. STAGE TWO: AVIATIONSTACK (SCHEDULE/STATUS) ---
    # Triggered if the plane is still at the gate or out of radar range.
    echo "⚠️ No Radar data. Checking Schedule..."
    AV_RES=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$AVSTACK_KEY&flight_iata=$FLIGHT_IATA")
    DATA=$(echo "$AV_RES" | jq -r ".data[0]? // empty")

    if [[ -n "$DATA" && "$DATA" != "null" ]]; then
        STATUS=$(echo "$DATA" | jq -r '.flight_status')
        # Extracts scheduled departure and arrival airport
        DEP_TIME=$(echo "$DATA" | jq -r '.departure.scheduled // "N/A"')
        ARR_IATA=$(echo "$DATA" | jq -r '.arrival.iata // "N/A"')

        # ${STATUS^^} converts the status to all-caps for the notification.
        MSG="📋 $FLIGHT_IATA Status: ${STATUS^^}
To: $ARR_IATA
Sched. Dep: ${DEP_TIME:11:5}
(No live GPS data yet)"
    else
        # Triggered if the flight code is invalid or not in either database.
        MSG="❌ $FLIGHT_IATA: No data found on any provider."
    fi
fi

# --- 3. DISPATCH ---
# Sends the final status report to your phone via the public ntfy cloud.
curl -s -d "$MSG" ntfy.sh/$NTFY_TOPIC
