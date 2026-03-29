#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 OFFICIAL ALIASES & UTILITIES
# ==========================================================
# PURPOSE:
# This file defines shorthand commands for the Pi 5 scripts.
# It ensures all custom automations are easy to run manually.
# ==========================================================

# --- DASHBOARD & MONITORING ---
# Quick access to the system status dashboard
alias db='/home/pi/scripts/pi-dashboard.sh'
alias dashboard='/home/pi/scripts/pi-dashboard.sh'

# --- MAINTENANCE & RECOVERY ---
# Manually triggers the local repository synchronization
alias sync='bash /home/pi/scripts/pi_sync.sh'

# Runs the full system rebuild or recovery script
alias rebuild='bash /home/pi/scripts/pi_rebuild.sh'

# Runs the system-wide update script
alias update='bash /home/pi/scripts/pi_update.sh'

# Reloads the bash profile to apply changes immediately
alias refresh='source ~/.bashrc && echo "✅ Environment refreshed."'

alias reinstall='bash ~/scripts/install.sh'

# --- SERVICE MANAGEMENT ---
# cycle: A function to hard-restart the ntfy listener.
# It kills any active instance and restarts it in the background.
# Output is redirected to /home/pi/ntfy.log for debugging.
cycle() {
    echo "🔄 Cycling Listener..."
    pkill -f ntfy_listener.sh
    sleep 1
    nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &
    echo "✅ Listener restarted."
}

# --- BASH INTEGRATION ---
# This block checks if this file is sourced in your .bashrc.
# If not, it adds it so these aliases work on every login.
if ! grep -q "scripts/aliases.sh" ~/.bashrc; then
    echo "source /home/pi/scripts/aliases.sh" >> ~/.bashrc
fi
