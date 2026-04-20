#!/bin/bash
# ==========================================================
# GLADSTONE NAKED RESET (cleanup_test.sh)
# ==========================================================

# 0. STEP OUT OF THE SPLASH ZONE
# This moves the script's execution context to the home folder
# so it doesn't try to delete the floor it's standing on.
cd /home/pi || exit

echo "??  [$HOSTNAME] WARNING: Commencing Full System Purge..."
sleep 2

# 1. Kill Persistent Services
echo "?? Stopping ntfy_listener and background tasks..."
pkill -f ntfy_listener.sh 2>/dev/null
pkill -f pi_services_manager.sh 2>/dev/null

# 2. Wipe the Crontab
echo "?? Clearing all Crontab entries..."
crontab -r 2>/dev/null

# 3. Remove the Identity "ID Card"
rm -f "$HOME/.gladstone_mode"

# 4. Clear Temporary Files
rm -f /tmp/service_retries

# 5. Remove Data & Logs
rm -rf /home/pi/printer_data
rm -rf /home/pi/homeasset
rm -rf /home/pi/invidious

# 6. Delete the Script Tree
# Now that we are in /home/pi, this will run cleanly.
if [ -d "$HOME/scripts" ]; then
    echo "?? Deleting ~/scripts..."
    rm -rf "$HOME/scripts"
fi

# 7. Clean up .bashrc
sed -i '/scripts\/aliases.sh/d' ~/.bashrc

echo "-------------------------------------------------------"
echo "? [$HOSTNAME] System is now NAKED."
echo "-------------------------------------------------------"


# Add this to the end of your cleanup_test.sh
if command -v docker &> /dev/null; then
    echo "?? Found Docker. Should I wipe all containers/volumes? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        docker system prune -af --volumes
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
fi