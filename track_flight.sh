#!/bin/bash
# Status-Aware Flight Tracker (Handles Scheduled vs. Active)

FLIGHT_IATA=$(echo "${1:-DL1660}" | tr '[:lower:]' '[:upper:]')
DEST_FILTER=$(echo "${2}" | tr '[:lower:]' '[:upper:]')
AIRLABS_KEY="4dc4b2db-5edb-432d-b858-50b9aa4e3afd"
AVSTACK_KEY="YOUR_AVIATIONSTACK_API_KEY"
NTFY_TOPIC="patrick_mitch_pi5_x9k2v_alerts"

echo "✈️ Querying $FLIGHT_IATA..."

# 1. Try Airlabs (Active Radar)
AIR_RES=$(curl -s "https://airlabs.co/api/v9/flight?flight_iata=$FLIGHT_IATA&api_key=$AIRLABS_KEY")
DATA=$(echo "$AIR_RES" | jq -r ".response // empty")

if [[ -n "$DATA" && "$DATA" != "null" ]]; then
    STATUS=$(echo "$DATA" | jq -r '.status')
    LAT=$(echo "$DATA" | jq -r '.lat')
    LNG=$(echo "$DATA" | jq -r '.lng')
    ALT=$(echo "$DATA" | jq -r '.alt')
    MSG="✈️ $FLIGHT_IATA (Live Radar)
Status: $STATUS
Alt: ${ALT}ft | Loc: $LAT, $LNG"
else
    # 2. Fallback to Aviationstack (Schedule/Status)
    echo "⚠️ No Radar data. Checking Schedule..."
    AV_RES=$(curl -s "http://api.aviationstack.com/v1/flights?access_key=$AVSTACK_KEY&flight_iata=$FLIGHT_IATA")
    DATA=$(echo "$AV_RES" | jq -r ".data[0]? // empty")
    
    if [[ -n "$DATA" && "$DATA" != "null" ]]; then
        STATUS=$(echo "$DATA" | jq -r '.flight_status')
        DEP_TIME=$(echo "$DATA" | jq -r '.departure.scheduled // "N/A"')
        ARR_IATA=$(echo "$DATA" | jq -r '.arrival.iata // "N/A"')
        
        MSG="📋 $FLIGHT_IATA Status: ${STATUS^^}
To: $ARR_IATA
Sched. Dep: ${DEP_TIME:11:5}
(No live GPS data yet)"
    else
        MSG="❌ $FLIGHT_IATA: No data found on any provider."
    fi
fi

curl -s -d "$MSG" ntfy.sh/$NTFY_TOPIC
