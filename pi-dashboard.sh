#!/bin/bash

# ==========================================================
# GLADSTONE CONTROL CENTER (pi-dashboard.sh)
# ==========================================================
# Version: 1.2.0
# Logic: Architecture-aware vitals, Printer stats, 
#        Network Speed, and Permission Integrity Check.
# ==========================================================

generate_dashboard() {
    echo "------------------------------------------------------------"
    echo "  Gladstone Control Center ($HOSTNAME)     $(date)"
    echo "------------------------------------------------------------"

    # --- 1. ARCHITECTURE AWARE VITALS ---
    IP=$(hostname -I | awk '{print $1}')

    if command -v vcgencmd >/dev/null; then
        TEMP=$(vcgencmd measure_temp | grep -oP '\d+\.\d+')Â°C
    else
        TEMP=$(sensors 2>/dev/null | grep -m1 "Package id 0" | grep -oP '\+\K\d+\.\d+')Â°C
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
        echo -e "☁️  LAST CLOUD SYNC: $(cat $SYNC_LOG)"
    else
        echo -e "☁️  LAST CLOUD SYNC: Never"
    fi

    BACKUP_DIR="/mnt/network_backups/CentralServer"
    BACKUP_LOG="/home/pi/scripts/logs/pi_backup.log"

    LAST_BACKUP_INFO=""
    if [ -d "$BACKUP_DIR" ]; then
        LAST_FILE=$(ls -t "$BACKUP_DIR"/gladstone_backup_*.tar.gz 2>/dev/null | head -n 1)
        if [ -n "$LAST_FILE" ]; then
            LAST_TIME=$(date -r "$LAST_FILE" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            LAST_SIZE=$(du -sh "$LAST_FILE" 2>/dev/null | awk '{print $1}')
            FNAME=$(basename "$LAST_FILE")
            LAST_BACKUP_INFO="$LAST_TIME ($LAST_SIZE | $FNAME)"
        fi
    fi

    if [ -z "$LAST_BACKUP_INFO" ] && [ -f "$BACKUP_LOG" ]; then
        SUCCESS_LINE=$(grep "Main Archive:" "$BACKUP_LOG" 2>/dev/null | grep "(SUCCESS)" | tail -n 1)
        if [ -n "$SUCCESS_LINE" ]; then
            LOG_TIME=$(echo "$SUCCESS_LINE" | cut -d']' -f1 | tr -d '[')
            FNAME=$(echo "$SUCCESS_LINE" | awk '{print $6}')
            LAST_BACKUP_INFO="$LOG_TIME ($FNAME)"
        fi
    fi

    if [ -n "$LAST_BACKUP_INFO" ]; then
        echo -e "📦  LAST SUCCESSFUL BACKUP: $LAST_BACKUP_INFO"
    else
        echo -e "📦  LAST SUCCESSFUL BACKUP: Never / No Backups Found"
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
    echo "[ REMOTE ] (ntfy):"
    echo "   - flight: Track a specific flight"
    echo "   - health: Check printer status"
    echo "   - sync: Trigger repository sync"
    echo "   - cycle: Restart command listener"
    echo "   - reinstall: Force update and rebuild"
    echo "[ LOCAL ] (Bash):"
    echo "   - refresh: Reload terminal environment"
    echo "   - update: Update OS and Software"
    echo "   - db: Launch this dashboard"
    echo "   - sync: Trigger repository sync"
    echo "   - cycle: Restart command listener"
    echo "   - rebuild: Rebuild docker containers"
    echo "------------------------------------------------------------"
}

# Run and print to terminal (as is)
generate_dashboard

# Ensure output directory exists
mkdir -p "$HOME/dashboard"

# Write clean text to file (stripping ANSI color codes)
generate_dashboard | sed -E "s/$(printf '\033')\[[0-9;]*[a-zA-Z]//g" > "$HOME/dashboard/dashboard.txt"
