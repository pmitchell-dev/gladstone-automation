#!/bin/bash
# RPi5 Dynamic Dashboard - Terminal + ntfy Push

# --- DATA GATHERING ---
UPTIME=$(uptime -p | sed 's/up //')
TEMP=$(vcgencmd measure_temp | cut -d'=' -f2)
DISK=$(df -h / | awk 'NR==2 {print $5}')
MEM=$(free -m | awk 'NR==2 {printf "%.0f%%", $3*100/$2}')

WORKSPACE_FILE="/home/pi/.openclaw/workspace/printer_status.html"
if [ -f "$WORKSPACE_FILE" ]; then
    TONER=$(grep 'tonerremain' "$WORKSPACE_FILE" | grep -o 'height="[0-9]*"' | cut -d'"' -f2)
    PRINTER="Online ($TONER%)"
else
    PRINTER="No data"
fi

if pgrep -f "ntfy_listener.sh" > /dev/null; then
    LISTENER="✅ Running"
else
    LISTENER="❌ Stopped"
fi

# --- CONSTRUCT DASHBOARD ---
DASHBOARD="📊 RPI5 STATS
Temp: $TEMP
Up: $UPTIME
Disk: $DISK | RAM: $MEM

🖨️ PRINTER: $PRINTER
⚙️ LISTENER: $LISTENER

📱 REMOTE COMMANDS:
- 'help'   -> Show this guide on phone
- health (Check Printer)
- alert (Ping Pi)"

# --- EXECUTION LOGIC ---
if [ "$1" == "push" ]; then
    # SEND TO PHONE
    curl -s -d "$DASHBOARD" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts > /dev/null
    echo "Dashboard pushed to ntfy! 📱"
else
    # SHOW ON TERMINAL (LOGIN)
    echo "========================================="
    echo "🏠 RPI5 MASTER DASHBOARD"
    echo "========================================="
    echo "$DASHBOARD"
    echo "========================================="
fi
