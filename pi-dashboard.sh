#!/bin/bash
# Gladstone Pi 5 Terminal Dashboard

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Data Gathering
IP_ADDR=$(hostname -I | awk '{print $1}')
CPU_TEMP=$(vcgencmd measure_temp | egrep -o '[0-9.]+')
MEM_USAGE=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)", $3,$2,$3*100/$2 }')
DISK_USAGE=$(df -h / | awk 'NR==2{print $3 "/" $2}')
UPTIME=$(uptime -p)

# Get Last Sync Time from Git
LAST_SYNC=$(git -C /home/pi/scripts log -1 --format="%cd" --date=format:"%Y-%m-%d %H:%M" 2>/dev/null || echo "Never")

echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${GREEN}  Gladstone Pi 5 Control Center${NC}          ${YELLOW}$(date)${NC}"
echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "🌐 IP: $IP_ADDR    🌡️ Temp: $CPU_TEMP°C    💾 Disk: $DISK_USAGE"
echo -e "🧠 Mem: $MEM_USAGE    🕒 Uptime: $UPTIME"
echo -e "${CYAN}------------------------------------------------------------${NC}"

# Active Flights Section
ACTIVE_FLIGHTS=$(pgrep -a -f "track_flight.sh" | grep -v "pgrep" | awk '{print $3}' | tr '\n' ' ' | xargs)
if [ -z "$ACTIVE_FLIGHTS" ]; then ACTIVE_FLIGHTS="None"; fi
echo -e "✈️  ACTIVE TRACKING: ${YELLOW}$ACTIVE_FLIGHTS${NC}"
echo -e "☁️  LAST CLOUD SYNC: ${GREEN}$LAST_SYNC${NC}"
echo ""
echo "📱 REMOTE COMMANDS (via ntfy):"
echo "- 'help'      -> Show command guide on phone"
echo "- 'status'    -> Push this dashboard to ntfy"
echo "- 'sync'      -> Backup scripts to GitHub"
echo "- 'reinstall' -> Refresh all scripts/crontabs"
echo -e "${CYAN}------------------------------------------------------------${NC}"
