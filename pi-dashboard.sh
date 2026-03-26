#!/bin/bash
# Gladstone Pi 5 Control Center - 2026 
echo "------------------------------------------------------------"
echo "  Gladstone Pi 5 Control Center          $(date)"
echo "------------------------------------------------------------"

# 1. Vitals
IP=$(hostname -I | awk '{print $1}')
TEMP=$(vcgencmd measure_temp | egrep -o '[0-9]*\.[0-9]*')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -m | awk 'NR==2 {printf "%s/%sMB (%.2f%%)", $3, $2, $3*100/$2}')
echo -e "🌐 IP: $IP    🌡️ Temp: ${TEMP}°C    💾 Disk: $DISK"
echo -e "🧠 Mem: $MEM    🕒 Uptime: $(uptime -p)"
echo "------------------------------------------------------------"

# 2. Activity
if pgrep -f "track_flight.sh" > /dev/null; then
    echo -e "✈️  ACTIVE TRACKING: $(pgrep -f track_flight.sh | wc -l) flight(s)"
else
    echo -e "✈️  ACTIVE TRACKING: None"
fi
[ -f "/home/pi/last_sync.log" ] && echo -e "☁️  LAST CLOUD SYNC: $(cat /home/pi/last_sync.log)"
echo "------------------------------------------------------------"

# 3. Printer
echo -e "\e[1;34m[ Brother Printer ]\e[0m"
STATUS_FILE="/home/pi/printer_data/status.html"
if [ -f "$STATUS_FILE" ]; then
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)
    if [[ -n "$HEIGHT" ]]; then
        TONER=$(( HEIGHT * 100 / 56 )); [[ "$TONER" -gt 100 ]] && TONER=100
        echo " - Status: ${P_STATUS:-Ready} | Toner: $TONER%"
    else
        echo " - Status: ${P_STATUS:-Ready} | Toner: Detected"
    fi
else
    echo " - Status: Offline"
fi
echo "------------------------------------------------------------"

# 4. Remote (Phone)
echo "📱 REMOTE COMMANDS:"
echo "- 'flight [ID]' -> Track flight     - 'health' -> Printer Status"
echo "- 'sync'        -> GitHub Sync      - 'cycle'  -> Reset Listener"
echo "- 'reinstall'   -> Full Rebuild"
echo "------------------------------------------------------------"

# 5. Local (PuTTY)
echo "⌨️  LOCAL ALIASES:"
echo "  db      (Dashboard)    cycle   (Reset Listener)"
echo "  sync    (GitHub Push)  sniff   (Dog Park Tracker)"
echo "  rebuild (Full Reset)"
echo "------------------------------------------------------------"
