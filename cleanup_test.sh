#!/bin/bash
# ==========================================================
# GLADSTONE NAKED RESET (cleanup_test.sh)
# ==========================================================

# 0. STEP OUT OF THE SPLASH ZONE
cd "$HOME" || exit

echo "⚠️  [$HOSTNAME] WARNING: Commencing Full System Purge..."
sleep 2

# 1. Kill Persistent Services
echo "🛑 Stopping ntfy_listener and background tasks..."
pkill -f ntfy_listener.sh 2>/dev/null
pkill -f pi_services_manager.sh 2>/dev/null
pkill -f nvr_syslog.py 2>/dev/null

# 2. Stop Docker Compose Stacks if Docker exists
if command -v docker &> /dev/null; then
    echo "🐳 Stopping active Docker container stacks..."
    for app in relayit homeasset jobboard gemini-api rustdesk dozzle hivemind; do
        if [ -d "$HOME/$app" ]; then
            (cd "$HOME/$app" && docker compose down --remove-orphans 2>/dev/null || true)
        fi
    done
fi

# 3. Wipe the Crontab
echo "🧹 Clearing all Crontab entries..."
crontab -r 2>/dev/null

# 4. Remove the Identity "ID Card"
rm -f "$HOME/.gladstone_mode"

# 5. Clear Temporary Files & Retries
rm -f /tmp/service_retries
rm -f /tmp/gladstone_ntfy_mute
rm -f /tmp/jobs.json.bak

# 6. Remove Data & Application Repositories/Directories
echo "🗑️ Deleting application directories & data..."
rm -rf "$HOME/printer_data"
rm -rf "$HOME/relayit"
rm -rf "$HOME/homeasset"
rm -rf "$HOME/jobboard"
rm -rf "$HOME/gemini-api"
rm -rf "$HOME/rustdesk"
rm -rf "$HOME/dozzle"
rm -rf "$HOME/hivemind"

# 7. Delete the Script Tree
if [ -d "$HOME/scripts" ]; then
    echo "🗑️ Deleting ~/scripts..."
    rm -rf "$HOME/scripts"
fi

# 8. Clean up .bashrc
sed -i '/scripts\/aliases.sh/d' ~/.bashrc

echo "-------------------------------------------------------"
echo "✅ [$HOSTNAME] System cleanup complete."
echo "-------------------------------------------------------"

if command -v docker &> /dev/null; then
    echo "🐳 Found Docker. Should I wipe all unused containers, volumes, and prune docker system? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        docker system prune -af --volumes
    fi
fi