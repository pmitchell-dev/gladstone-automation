#!/bin/bash
# Advanced Brother Printer Health Check
STATUS_FILE="/home/pi/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# 1. Refresh the data
bash /home/pi/scripts/get_printer_status.sh > /dev/null

if [ ! -f "$STATUS_FILE" ]; then
    HEALTH_REPORT="⚠️ Printer data missing. Check connection to 192.168.50.56."
else
    # 2. Extract Toner Percentage
    # We look for a number (0-100) followed by a % sign
    TONER_PCT=$(grep -oP '\d+(?=%)' "$STATUS_FILE" | head -n 1)
    
    # Fallback: If no % found, look for height/width attributes often used for bars
    if [[ -z "$TONER_PCT" ]]; then
        TONER_PCT=$(grep -i "toner" "$STATUS_FILE" | grep -oP 'width="\K[0-9]+' | head -n 1)
    fi

    # 3. Extract Status (More aggressive search)
    # This looks for common Brother status words even if they are inside tags
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep|Manual|Offline|Error" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)

    # 4. Extract Paper Status
    PAPER=$(grep -Ei "Tray 1|Paper" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)

    # Format the message
    # If TONER_PCT is empty, we show a friendly warning
    TONER_VAL="${TONER_PCT:-??}%"
    
    HEALTH_REPORT="🖨️ Brother Health Check:
--------------------------
📊 Status: ${P_STATUS:-Ready}
💧 Toner: $TONER_VAL Remaining
📄 Paper: ${PAPER:-OK}
--------------------------"
fi

# Send to ntfy
curl -s -d "$HEALTH_REPORT" ntfy.sh/$TOPIC > /dev/null
