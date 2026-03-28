#!/bin/bash

# ==========================================================
# GLADSTONE CONTROL CENTER (pi-dashboard.sh)
# ==========================================================
# Version: 1.2.0
# Logic: Architecture-aware vitals, Printer stats, 
#        Network Speed, and Permission Integrity Check.
# ==========================================================

echo "------------------------------------------------------------"
echo "  Gladstone Control Center ($HOSTNAME)     $(date)"
echo "------------------------------------------------------------"

# --- 1. ARCHITECTURE AWARE VITALS ---
IP=$(hostname -I | awk '{print $1}')

if command -v vcgencmd >/dev/null; then
    TEMP=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')°C
else
    TEMP=$(sensors 2>/dev/null | grep -m1 "Package id 0" | grep -oP '\+\K\d+\.\d+')°C
    [[ -z "$TEMP" ]] && TEMP="N/A"
fi

DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -h | awk 'NR==2 {print $3 "/" $2}')

echo -e "?? IP: $IP    ??? Temp: $TEMP    ?? Disk: $DISK"
echo -e "?? Mem: $MEM    ?? Uptime: $(uptime -p)"

# --- NETWORK SPEED STATUS ---
SPEED_LOG="/home/pi/scripts/logs/net_speed.log"
if [ -f "$SPEED_LOG" ]; then
    DOWNLOAD=$(grep "Download" "$SPEED_LOG" | awk '{print $2}')
    UPLOAD=$(grep "Upload" "$SPEED_LOG" | awk '{print $2}')
    echo -e "?? Speed: ? $DOWNLOAD Mbps | ? $UPLOAD Mbps"
else
    echo -e "?? Speed: No data (Run 'net_speed.sh' manually)"
fi
echo "------------------------------------------------------------"

# --- 1.5 SYSTEM HEALTH & PERMISSIONS ---
# Check for files NOT owned by the current user in the scripts folder
BAD_OWNER=$(find /home/pi/scripts -not -user $USER | wc -l)
LOG_WRITE=$( [ -w "/home/pi/scripts/logs" ] && echo "OK" || echo "LOCKED" )

if [ "$BAD_OWNER" -gt 0 ]; then
    echo -e "??  SECURITY: $BAD_OWNER files have wrong ownership! (Run 'reinstall')"
else
    echo -e "? PERMISSIONS: All files owned by $USER"
fi

if [ "$LOG_WRITE" == "LOCKED" ]; then
    echo -e "? LOGGING: Scripts cannot write to logs/ folder!"
fi
echo "------------------------------------------------------------"

# --- 2. ACTIVITY & CLOUD STATUS ---
if pgrep -f "track_flight.sh" > /dev/null; then
    echo -e "??  ACTIVE TRACKING: $(pgrep -f track_flight.sh | wc -l) flight(s)"
else
    echo -e "??  ACTIVE TRACKING: None"
fi

SYNC_LOG="/home/pi/scripts/logs/last_sync.log"
if [ -f "$SYNC_LOG" ]; then
    echo -e "??  LAST CLOUD SYNC: $(cat $SYNC_LOG)"
else
    echo -e "??  LAST CLOUD SYNC: Never"
fi
echo "------------------------------------------------------------"

# --- 3. BROTHER PRINTER SECTION ---
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

# --- 4. QUICK REFERENCE ---
echo "?? REMOTE (ntfy): flight, health, sync, cycle, reinstall"
echo "??  LOCAL (Bash): refresh, update, db, sync, cycle, rebuild"
echo "------------------------------------------------------------"