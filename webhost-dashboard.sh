#!/bin/bash

# ==========================================================
# WEBHOST CONTROL CENTER (webhost-dashboard.sh)
# ==========================================================
# Version: 1.1.0
# Logic: Server identification and local command reference.
# ==========================================================

# Color Definitions
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

generate_dashboard() {
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo -e "  ${GREEN}Webhost Server ($HOSTNAME)${NC}      $(date)"
    echo -e "${CYAN}------------------------------------------------------------${NC}"

    IP=$(hostname -I | awk '{print $1}')
    DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
    MEM=$(free -h | awk 'NR==2 {print $3 "/" $2}')

    echo -e "🌐 ${YELLOW}IP:${NC} $IP    💾 ${YELLOW}Disk:${NC} $DISK"
    echo -e "🧠 ${YELLOW}Mem:${NC} $MEM    🚀 ${YELLOW}Uptime:${NC} $(uptime -p)"

    BACKUP_DIR="/mnt/backups/laptopwebhost"
    if [ -d "$BACKUP_DIR" ]; then
        LAST_FILE=$(ls -t "$BACKUP_DIR"/gladstone_backup_*.tar.gz 2>/dev/null | head -n 1)
        if [ -n "$LAST_FILE" ]; then
            LAST_TIME=$(date -r "$LAST_FILE" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c %y "$LAST_FILE" 2>/dev/null | cut -d. -f1)
            LAST_SIZE=$(du -sh "$LAST_FILE" 2>/dev/null | awk '{print $1}')
            FNAME=$(basename "$LAST_FILE")
            echo -e "📦 ${YELLOW}Last Successful Backup:${NC} $LAST_TIME ($LAST_SIZE | $FNAME)"
        else
            echo -e "📦 ${YELLOW}Last Successful Backup:${NC} No backups found"
        fi
    else
        echo -e "📦 ${YELLOW}Last Successful Backup:${NC} Target path $BACKUP_DIR unavailable"
    fi

    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo -e "${BLUE}[ DOCKER CONTAINERS ]${NC}"
    if command -v docker &> /dev/null; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "   ${YELLOW}Docker is not installed.${NC}"
    fi

    echo -e "${CYAN}------------------------------------------------------------${NC}"
    echo -e "${BLUE}[ LOCAL COMMANDS ] (Bash):${NC}"
    echo -e "   - ${GREEN}refresh:${NC} Reload terminal environment (aliases/paths)"
    echo -e "   - ${GREEN}update:${NC}  Fetch and install system updates"
    echo -e "   - ${GREEN}db:${NC}      Launch this webhost dashboard"
    echo -e "   - ${GREEN}sync:${NC}    Backup codebase to GitHub repository"
    echo -e "   - ${GREEN}rebuild:${NC} Pull latest code and re-deploy Docker containers"
    echo -e "${CYAN}------------------------------------------------------------${NC}"
}

# Run and print to terminal (as is)
generate_dashboard

# Ensure output directory exists
mkdir -p "$HOME/dashboard"

# Write clean text to file (stripping ANSI color codes)
generate_dashboard | sed -E "s/\$(printf '\033')\[[0-9;]*[a-zA-Z]//g" > "$HOME/dashboard/dashboard.txt"
