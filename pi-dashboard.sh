#!/bin/bash

# ==========================================================
# GLADSTONE CONTROL CENTER (DASHBOARD)
# ==========================================================
# PURPOSE:
# A unified system monitor that displays hardware vitals,
# active flight tracking status, cloud backup history,
# and Brother printer health at a glance.
#
# COMPATIBILITY:
# Supports both ARM (Raspberry Pi 5) and x86 (Laptop) logic.
# ==========================================================

echo "------------------------------------------------------------"
echo "  Gladstone Control Center                $(date)"
echo "------------------------------------------------------------"

# --- 1. ARCHITECTURE AWARE VITALS ---
# Grabs the primary local IP address of the machine
IP=$(hostname -I | awk '{print $1}')

# TEMPERATURE DETECTION LOGIC:
# If 'vcgencmd' exists, we are on a Pi. If not, we use 'sensors' for a laptop.
if command -v vcgencmd >/dev/null; then
    # Raspberry Pi 5 specific temperature command
    TEMP=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')°C
else
    # x86 Laptop fallback (requires 'lm-sensors' package)
    TEMP=$(sensors 2>/dev/null | grep -m1 "Package id 0" | grep -oP '\+\K\d+\.\d+')°C
    [[ -z "$TEMP" ]] && TEMP="N/A"
fi

# DISK & MEMORY USAGE:
# Formats output as "Used / Total" (e.g., 5GB / 30GB)
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -h | awk 'NR==2 {print $3 "/" $2}')

echo -e "🌐 IP: $IP    🌡️ Temp: $TEMP    💾 Disk: $DISK"
echo -e "🧠 Mem: $MEM    🕒 Uptime: $(uptime -p)"
echo "------------------------------------------------------------"

# --- 2. ACTIVITY & CLOUD STATUS ---
# Checks the process list for any active flight tracking instances
if pgrep -f "track_flight.sh" > /dev/null; then
    echo -e "✈️  ACTIVE TRACKING: $(pgrep -f track_flight.sh | wc -l) flight(s)"
else
    echo -e "✈️  ACTIVE TRACKING: None"
fi

# Displays the timestamp from your latest successful GitHub backup
if [ -f "/home/pi/last_sync.log" ]; then
    echo -e "☁️  LAST CLOUD SYNC: $(cat /home/pi/last_sync.log)"
fi
echo "------------------------------------------------------------"

# --- 3. BROTHER PRINTER SECTION ---
# Displays the printer status parsed from your local scraper (status.html)
echo -e "\e[1;34m[ Brother Printer ]\e[0m"
STATUS_FILE="/home/pi/printer_data/status.html"

if [ -f "$STATUS_FILE" ]; then
    # Extracts current mode (Ready, Sleep, Deep Sleep)
    P_STATUS=$(grep -Ei "Ready|Sleep|Deep" "$STATUS_FILE" | sed -e 's/<[^>]*>//g' | xargs | head -n 1)
    
    # Calculates Toner % based on image height (56px = 100%)
    HEIGHT=$(grep -oP 'height="\K[0-9]+' "$STATUS_FILE" | head -n 3 | tail -n 1)
    if [[ -n "$HEIGHT" ]]; then
        TONER=$(( HEIGHT * 100 / 56 )); [[ "$TONER" -gt 100 ]] && TONER=100
        echo " - Status: ${P_STATUS:-Ready} | Toner: $TONER%"
    else
        # Fallback for 3rd party toner where height isn't provided
        echo " - Status: ${P_STATUS:-Ready} | Toner: Installed"
    fi
else
    echo " - Status: Offline (No status.html found)"
fi
echo "------------------------------------------------------------"

# --- 4. QUICK REFERENCE COMMAND LISTS ---
# A reminder of what commands you can send via ntfy vs. what aliases you have locally.
echo "📱 REMOTE (ntfy): flight, health, sync, cycle, reinstall"
echo "⌨️  LOCAL (Bash): refresh, update, db, sync, cycle, rebuild"
echo "------------------------------------------------------------"
