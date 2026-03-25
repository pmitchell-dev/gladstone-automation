#!/bin/bash
# Total Wipe - Returns VM to "Bare Metal" state

echo "🧹 Starting Deep Clean..."

# 1. Stop active processes
pkill -f ntfy_listener.sh
pkill -f track_flight.sh

# 2. Remove Files and Cron
rm -rf ~/scripts
rm -f ~/ntfy.log
rm -f ~/services_manager.log
crontab -r

# 3. Clean .bashrc (removes the dashboard and sync alias)
sed -i '/pi-dashboard.sh/d' ~/.bashrc
sed -i '/alias sync=/d' ~/.bashrc

# 4. Uninstall Dependencies (Checks both common names)
echo "📦 Uninstalling test dependencies..."
sudo apt purge -y jq bc ntfy ntfy-client 2>/dev/null
sudo apt autoremove -y

echo "✨ VM is now 'Naked'. Ready for a fresh bootstrap test."
