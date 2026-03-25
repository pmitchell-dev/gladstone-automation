#!/bin/bash
# RPi5 Printer & Network Watchdog (Quiet vs Verbose)

PRINTER_IP="192.168.50.56"
WORKSPACE_FILE="/home/pi/.openclaw/workspace/printer_status.html"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
MODE=$1  # Check if "manual" was passed as an argument

# 1. Network Check
if ! ping -c 1 -W 2 $PRINTER_IP > /dev/null; then
    TITLE="🚨 NETWORK ALERT"
    MESSAGE="Brother Printer ($PRINTER_IP) is OFFLINE."
    TAGS="rotating_light,error"
    PRIORITY="urgent"
else
    # 2. Toner Check
    HEIGHT=$(grep 'tonerremain' $WORKSPACE_FILE | grep -o 'height="[0-9]*"' | cut -d'"' -f2)
    THRESHOLD=10

    if [ -n "$HEIGHT" ] && [ "$HEIGHT" -lt "$THRESHOLD" ]; then
        TITLE="⚠️ LOW TONER ALERT"
        MESSAGE="Toner height is at $HEIGHT. Order soon!"
        TAGS="warning,printer"
        PRIORITY="high"
    elif [ "$MODE" == "manual" ]; then
        # 3. Manual Status Report (Only if called via 'health')
        TITLE="✅ PRINTER STATUS: OK"
        MESSAGE="Printer is online. Toner height: $HEIGHT (Threshold: $THRESHOLD)"
        TAGS="white_check_mark,printer"
        PRIORITY="low"
    fi
fi

# Send to ntfy if a message exists
if [ -n "$MESSAGE" ]; then
    curl -s -H "Title: $TITLE" -H "Priority: $PRIORITY" -H "Tags: $TAGS" \
         -d "$MESSAGE" ntfy.sh/$TOPIC > /dev/null
fi
