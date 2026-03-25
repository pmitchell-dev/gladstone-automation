#!/bin/bash
STATUS_FILE="/home/pi/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# Refresh the HTML
bash /home/pi/scripts/get_printer_status.sh > /dev/null

if [ ! -f "$STATUS_FILE" ]; then
    HEALTH_REPORT="⚠️ Printer Offline"
else
    # 1. Calculate Toner from the 'height' of the bar image
    # We look for the image heights and pick the one near the Toner Level section
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)
    
    # 2. Extract Device Status (Ready/Sleep)
    P_STATUS=$(grep -A 2 "Device Status" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | awk '{print $3}')
    
    # 3. Handle the "Non-Brother" label
    NON_GENUINE=$(grep -i "Non Brother Toner" "$STATUS_FILE")

    # 4. Math: Convert height to % (Assuming 56px = 100%)
    if [[ -n "$HEIGHT" && "$HEIGHT" -gt 0 ]]; then
        TONER_PCT=$(( HEIGHT * 100 / 56 ))
        # Cap it at 100
        [[ "$TONER_PCT" -gt 100 ]] && TONER_PCT=100
        TONER_VAL="$TONER_PCT%"
    elif [[ -n "$NON_GENUINE" ]]; then
        TONER_VAL="Installed (3rd Party)"
    else
        TONER_VAL="Unknown"
    fi

    HEALTH_REPORT="🖨️ Brother Health Check:
--------------------------
📊 Status: ${P_STATUS:-Sleep}
💧 Toner: $TONER_VAL
📄 Paper: OK
--------------------------"
fi

curl -s -d "$HEALTH_REPORT" ntfy.sh/$TOPIC > /dev/null
