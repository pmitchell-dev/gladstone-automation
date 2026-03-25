#!/bin/bash
echo "🧹 Starting Deep Clean..."

# Kill processes
pkill -f ntfy_listener.sh
pkill -f track_flight.sh

# Wipe the scripts folder AND any stray scripts in Home
rm -rf ~/scripts
rm -f ~/*.sh ~/*-help.txt ~/ntfy.log ~/services_manager.log

# Reset environment
crontab -r
sed -i '/pi-dashboard.sh/d' ~/.bashrc
sed -i '/alias sync=/d' ~/.bashrc

echo "✨ VM is now 'Naked'. All stray files removed."
