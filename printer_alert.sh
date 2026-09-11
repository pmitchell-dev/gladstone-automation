#!/bin/bash

# ==========================================================
# GLADSTONE PRINTER MONITOR (printer_alert.sh)
# ==========================================================

STATUS_FILE="/home/gladstone/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

if [ ! -f "$STATUS_FILE" ]; then
    exit 1
fi

# Search for error keywords
ERROR_MSG=$(grep -Ei "Paper Jam|No Paper|Cover Open|Replace Toner" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs)

if [[ -n "$ERROR_MSG" ]]; then
    # Updated: Includes Hostname and Priority Header
    curl -H "Priority: high" \
         -d "[$HOSTNAME] ??? Printer Alert: $ERROR_MSG" \
         https://ntfy.sh/$TOPIC
fi