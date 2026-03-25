#!/bin/bash
# Advanced Brother Printer Health Scraper
STATUS_FILE="/home/pi/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# 1. Grab fresh data
bash /home/pi/scripts/get_printer_status.sh > /dev/null

if [ ! -f "$STATUS_FILE" ]; then
    HEALTH_REPORT="⚠️ Printer data missing at 192.168.50.56."
else
    # 2. Extract Toner (Looking for % text, then pixel height as fallback)
    TONER_PCT=$(grep -oP '\d+(?=%)' "$STATUS_FILE" | head -n 1)
    
    # Fallback: Look for the 'height' of the toner bar (Common in Brother HTML)
    if [[ -z "$TONER_PCT" ]]; then
        # Brother often uses 56px as 100%. We'll look for a height near a 'toner' class.
        TONER_HEIGHT=$(grep -i "toner" "$STATUS_FILE" | grep -oP 'height="\K[0-9]+' | head -n 1)
        if [[ -n "$TONER_HEIGHT" ]]; then
            # Convert height to percentage (assuming 56 is max)
            TONER_PCT=$(( TONER_HEIGHT * 100 / 56 ))
        fi
    fi

    # 3. Extract Status (Adding Deep Sleep and Printing)
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep|Printing|Manual|Offline|Error" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)

    # 4. Extract Paper
    PAPER=$(grep -Ei "Tray 1|Paper|Standard" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)

    # Clean up the output
    TONER_VAL="${TONER_PCT:-??}%"
    
    HEALTH_REPORT="🖨️ Brother Health Check:
--------------------------
📊 Status: ${P_STATUS:-Ready}
💧 Toner: $TONER_VAL
📄 Paper: ${PAPER:-OK}
--------------------------"
fi

curl -s -d "$HEALTH_REPORT" ntfy.sh/$TOPIC > /dev/null
