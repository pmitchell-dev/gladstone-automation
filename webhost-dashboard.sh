#!/bin/bash

# ==========================================================
# WEBHOST CONTROL CENTER (webhost-dashboard.sh)
# ==========================================================
# Version: 1.0.0
# Logic: Server identification and local command reference.
# ==========================================================

echo "------------------------------------------------------------"
echo "  Webhost Server ($HOSTNAME)      $(date)"
echo "------------------------------------------------------------"

IP=$(hostname -I | awk '{print $1}')
DISK=$(df -h / | awk 'NR==2 {print $3 "/" $2}')
MEM=$(free -h | awk 'NR==2 {print $3 "/" $2}')

echo -e "🌐 IP: $IP    💾 Disk: $DISK"
echo -e "🧠 Mem: $MEM    🚀 Uptime: $(uptime -p)"

echo "------------------------------------------------------------"
echo "[ DOCKER CONTAINERS ]"
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "   Docker is not installed."
fi

echo "------------------------------------------------------------"
echo "[ LOCAL ] (Bash):"
echo "   - refresh: Reload terminal environment (aliases/paths)"
echo "   - update: Fetch and install system updates"
echo "   - db: Launch this webhost dashboard"
echo "   - sync: Backup codebase to GitHub repository"
echo "   - rebuild: Pull latest code and re-deploy Docker containers"
echo "------------------------------------------------------------"
