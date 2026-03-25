#!/bin/bash
# Brother Printer Status Monitor
STATUS_FILE="/home/pi/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# 1. Check if the status file exists
if [ ! -f "$STATUS_FILE" ]; then
    echo "⚠️ Status file not found. Run get_printer_status.sh first."
    exit 1
fi

# 2. Define Brother Error Keywords
# We use -qi to search quietly and ignore case
LOW_TONER=$(grep -Ei "Toner Low|Replace Toner|End of Life" "$STATUS_FILE")
OUT_OF_PAPER=$(grep -Ei "No Paper|Out of Paper|Load Paper" "$STATUS_FILE")
JAM=$(grep -Ei "Jam|Paper Jam" "$STATUS_FILE")

# 3. Logic: Send Notification based on findings
if [[ -n "$LOW_TONER" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: high" \
         -H "Tags: warning,printer" \
         -d "Toner is Low! You might need to grab a cartridge soon." \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Toner Low"

elif [[ -n "$OUT_OF_PAPER" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: default" \
         -H "Tags: package,printer" \
         -d "The printer is out of paper. Refill the tray!" \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Out of Paper"

elif [[ -n "$JAM" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: urgent" \
         -H "Tags: fire,printer" \
         -d "Paper Jam detected in the Brother printer!" \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Paper Jam"

else
    echo "✅ Printer status is Normal (No alerts needed)."
fi
