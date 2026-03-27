#!/bin/bash

# ==========================================================
# BROTHER PRINTER ALERT ENGINE (GLADSTONE PI 5)
# ==========================================================
# PURPOSE:
# Scans the captured printer HTML for specific error strings.
# If a problem is found, it sends an urgent ntfy alert.
# If everything is fine, it exits silently to avoid spam.
# ==========================================================

# --- CONFIGURATION ---
STATUS_FILE="/home/pi/printer_data/status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# 1. PRE-FLIGHT CHECK
# Ensures the scraper has actually created the data file before we try to read it.
if [ ! -f "$STATUS_FILE" ]; then
    echo "⚠️ Status file not found. Run get_printer_status.sh first."
    exit 1
fi

# 2. ERROR KEYWORD DETECTION
# -E: Use extended regex to check for multiple terms at once.
# -i: Ignore case (matches "Toner" or "toner").
LOW_TONER=$(grep -Ei "Toner Low|Replace Toner|End of Life" "$STATUS_FILE")
OUT_OF_PAPER=$(grep -Ei "No Paper|Out of Paper|Load Paper" "$STATUS_FILE")
JAM=$(grep -Ei "Jam|Paper Jam" "$STATUS_FILE")

# 3. NOTIFICATION LOGIC
# We only send a curl if a variable above is NOT empty (-n).

# --- CASE: TONER ISSUES ---
if [[ -n "$LOW_TONER" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: high" \
         -H "Tags: warning,printer" \
         -d "Toner is Low! You might need to grab a cartridge soon." \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Toner Low"

# --- CASE: PAPER ISSUES ---
elif [[ -n "$OUT_OF_PAPER" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: default" \
         -H "Tags: package,printer" \
         -d "The printer is out of paper. Refill the tray!" \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Out of Paper"

# --- CASE: MECHANICAL ISSUES ---
elif [[ -n "$JAM" ]]; then
    curl -s -H "Title: 🖨️ Brother Printer Alert" \
         -H "Priority: urgent" \
         -H "Tags: fire,printer" \
         -d "Paper Jam detected in the Brother printer!" \
         ntfy.sh/$TOPIC
    echo "🚨 Alert Sent: Paper Jam"

# --- CASE: ALL CLEAR ---
else
    echo "✅ Printer status is Normal (No alerts needed)."
fi
