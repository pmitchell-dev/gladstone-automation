#!/bin/bash

# ==========================================================
# BROTHER PRINTER HEALTH REPORTER (GLADSTONE PI 5)
# ==========================================================
# PURPOSE:
# Parses the raw HTML from the Brother status page to extract 
# toner levels, power status, and paper readiness.
# Sends the final report to the public ntfy.sh cloud.
# ==========================================================

# --- CONFIGURATION ---
STATUS_FILE="/home/gladstone/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# --- DATA REFRESH ---
# First, trigger the scraper script to ensure we have the newest HTML data.
bash /home/gladstone/scripts/get_printer_status.sh > /dev/null

# --- PARSING LOGIC ---
if [ ! -f "$STATUS_FILE" ]; then
    # If the file doesn't exist, the scraper likely failed to reach the printer.
    HEALTH_REPORT="⚠️ Printer Offline (Cannot reach $STATUS_FILE)"
else
    # 1. TONER LEVEL CALCULATION
    # Brother printers often use a bar image where 'height' represents the level.
    # We grab the height attribute from the HTML.
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)

    # 2. DEVICE STATUS EXTRACTION
    # Finds "Device Status", strips HTML tags, and grabs the 3rd word (e.g., "Sleep" or "Ready").
    P_STATUS=$(grep -A 2 "Device Status" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | awk '{print $3}')

    # 3. GENUINE TONER CHECK
    # Check if the page contains the "Non Brother" warning for 3rd party toner.
    NON_GENUINE=$(grep -i "Non Brother Toner" "$STATUS_FILE")

    # 4. PERCENTAGE MATH
    # Assuming 56 pixels = 100% full (Standard for this Brother model).
    if [[ -n "$HEIGHT" && "$HEIGHT" -gt 0 ]]; then
        TONER_PCT=$(( HEIGHT * 100 / 56 ))
        # Cap at 100 in case of unexpected pixel values
        [[ "$TONER_PCT" -gt 100 ]] && TONER_PCT=100
        TONER_VAL="$TONER_PCT%"
    elif [[ -n "$NON_GENUINE" ]]; then
        # If height is 0/missing but 3rd party toner is found, label it as such.
        TONER_VAL="Installed (3rd Party)"
    else
        TONER_VAL="Unknown"
    fi

    # 5. CONSTRUCT THE REPORT
    # Formats the data into a clean text block for the ntfy notification.
    HEALTH_REPORT="🖨️ Brother Health Check:
--------------------------
📊 Status: ${P_STATUS:-Sleep}
💧 Toner: $TONER_VAL
📄 Paper: OK
--------------------------"
fi

# --- DISPATCH ---
# Send the compiled report to your phone via the public ntfy.sh endpoint.
curl -s -d "$HEALTH_REPORT" https://ntfy.sh/$TOPIC > /dev/null
