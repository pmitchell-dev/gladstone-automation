#!/bin/bash
# Gladstone Pi 5 Control Center - Full Version
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

# 2. Flight & Activity Section
if pgrep -f "track_flight.sh" > /dev/null; then
    FLIGHTS=$(pgrep -f "track_flight.sh" | wc -l)
    echo -e "✈️  ACTIVE TRACKING: $FLIGHTS flight(s) in progress"
else
    echo -e "✈️  ACTIVE TRACKING: None"
fi

if [ -f "/home/pi/last_sync.log" ]; then
    echo -e "☁️  LAST CLOUD SYNC: $(cat /home/pi/last_sync.log)"
fi
echo "------------------------------------------------------------"

# 3. Brother Printer Section
echo -e "\e[1;34m[ Brother Printer ]\e[0m"
STATUS_FILE="/home/pi/printer_data/status.html"
if [ -f "$STATUS_FILE" ]; then
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)
    if [[ -n "$HEIGHT" ]]; then
        TONER_PCT=$(( HEIGHT * 100 / 56 )); [[ "$TONER_PCT" -gt 100 ]] && TONER_PCT=100
        echo " - Status: ${P_STATUS:-Ready} | Toner: $TONER_PCT%"
    else
        echo " - Status: ${P_STATUS:-Ready} | Toner: Detected"
    fi
else
    echo " - Status: Offline / No Data"
fi
echo "------------------------------------------------------------"

# 4. Remote Commands (via ntfy)
echo "📱 REMOTE COMMANDS:"
echo "- 'flight [ID]' -> Track a live flight"
echo "- 'health'      -> Push printer status to phone"
echo "- 'sync'        -> Backup scripts to GitHub"
echo "- 'reinstall'   -> Refresh all scripts/crontabs"
echo "------------------------------------------------------------"

# 5. Local Shortcuts (PuTTY)
echo "⌨️  LOCAL ALIASES:"
echo "  db      (Dashboard)    cycle   (Reset Listener)"
echo "  sync    (GitHub Push)  sniff   (Dog Park Tracker)"
echo "  3dp     (3D Print Mon) rebuild (Full Script Reset)"
echo "------------------------------------------------------------"
