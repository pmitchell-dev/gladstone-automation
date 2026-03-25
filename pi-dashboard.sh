#!/bin/bash
# Gladstone Pi 5 Control Center - 2026 Stable
# ------------------------------------------------------------
echo "------------------------------------------------------------"
echo "  Gladstone Pi 5 Control Center          $(date)"
echo "------------------------------------------------------------"

# 1. System Vitals
IP=$(hostname -I | awk '{print $1}')
TEMP=$(vcgencmd measure_temp | egrep -o '[0-9]*\.[0-9]*')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -m | awk 'NR==2 {printf "%s/%sMB (%.2f%%)", $3, $2, $3*100/$2}')
UPTIME=$(uptime -p)

echo -e "🌐 IP: $IP    🌡️ Temp: ${TEMP}°C    💾 Disk: $DISK"
echo -e "🧠 Mem: $MEM    🕒 Uptime: $UPTIME"
echo "------------------------------------------------------------"

# 2. Flight Tracking Section
if pgrep -f "track_flight.sh" > /dev/null; then
    FLIGHTS=$(pgrep -f "track_flight.sh" | wc -l)
    echo -e "✈️  ACTIVE TRACKING: $FLIGHTS flight(s) in progress"
else
    echo -e "✈️  ACTIVE TRACKING: None"
fi

# 3. Cloud Sync Status
if [ -f "/home/pi/last_sync.log" ]; then
    LAST_SYNC=$(cat /home/pi/last_sync.log)
    echo -e "☁️  LAST CLOUD SYNC: $LAST_SYNC"
else
    echo -e "☁️  LAST CLOUD SYNC: Never"
fi
echo "------------------------------------------------------------"

# 4. Brother Printer Section
echo -e "\e[1;34m[ Brother Printer ]\e[0m"
STATUS_FILE="/home/pi/printer_data/status.html"

if [ -f "$STATUS_FILE" ]; then
    # Grab the visual height of the toner bar
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)
    # Grab the text status (Sleep/Ready/Deep Sleep)
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)
    
    if [[ -n "$HEIGHT" ]]; then
        TONER_PCT=$(( HEIGHT * 100 / 56 ))
        [[ "$TONER_PCT" -gt 100 ]] && TONER_PCT=100
        echo " - Status: ${P_STATUS:-Ready} | Toner: $TONER_PCT%"
    else
        echo " - Status: ${P_STATUS:-Ready} | Toner: Detected"
    fi
else
    echo " - Status: Offline / No Data"
fi
echo "------------------------------------------------------------"

# 5. Remote Commands Reminder
echo "📱 REMOTE COMMANDS (via ntfy):"
echo "- 'help'      -> Show command guide on phone"
echo "- 'health'    -> Push printer status to ntfy"
echo "- 'sync'      -> Backup scripts to GitHub"
echo "- 'reinstall' -> Refresh all scripts/crontabs"
echo "------------------------------------------------------------"
