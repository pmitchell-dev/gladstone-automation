#!/bin/bash
# Gladstone Control Center (Pi 5 & x86 Laptop Compatible)
# ------------------------------------------------------------
echo "------------------------------------------------------------"
echo "  Gladstone Control Center               $(date)"
echo "------------------------------------------------------------"

# 1. Architecture Aware Vitals
IP=$(hostname -I | awk '{print $1}')

# Temperature Detection
if command -v vcgencmd >/dev/null; then
    TEMP=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')°C
else
    # x86 Laptop fallback (requires lm-sensors)
    TEMP=$(sensors 2>/dev/null | grep -m1 "Package id 0" | grep -oP '\+\K\d+\.\d+')°C
    [[ -z "$TEMP" ]] && TEMP="N/A"
fi

# RAM and Disk
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -h | awk 'NR==2 {print $3 "/" $2}')

echo -e "🌐 IP: $IP    🌡️ Temp: $TEMP    💾 Disk: $DISK"
echo -e "🧠 Mem: $MEM    🕒 Uptime: $(uptime -p)"
echo "------------------------------------------------------------"

# 2. Activity & Cloud Status
if pgrep -f "track_flight.sh" > /dev/null; then
    echo -e "✈️  ACTIVE TRACKING: $(pgrep -f track_flight.sh | wc -l) flight(s)"
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
        TONER=$(( HEIGHT * 100 / 56 )); [[ "$TONER" -gt 100 ]] && TONER=100
        echo " - Status: ${P_STATUS:-Ready} | Toner: $TONER%"
    else
        echo " - Status: ${P_STATUS:-Ready} | Toner: Installed"
    fi
else
    echo " - Status: Offline"
fi
echo "------------------------------------------------------------"

# 4. Command Lists
echo "📱 REMOTE (ntfy): flight, health, sync, cycle, reinstall"
echo "⌨️  LOCAL (Bash): refresh, update, db, sync, cycle, sniff, rebuild"
echo "------------------------------------------------------------"
