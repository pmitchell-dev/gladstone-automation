#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 OFFICIAL ALIASES & UTILITIES (v1.5)
# ==========================================================

# --- DASHBOARD & MONITORING ---
alias db='/home/pi/scripts/pi-dashboard.sh'
alias dashboard='/home/pi/scripts/pi-dashboard.sh'

# --- MAINTENANCE & RECOVERY ---
alias sync='bash /home/pi/scripts/pi_sync.sh'
alias rebuild='bash /home/pi/scripts/pi_rebuild.sh'
alias update='bash /home/pi/scripts/pi_update.sh'
alias reinstall='bash /home/pi/scripts/install.sh'
alias refresh='source ~/.bashrc && echo "? Environment refreshed."'

# --- COMMUNICATION & SERVICES ---
# Shorthand for the new relay script
alias relay='bash /home/pi/scripts/relay.sh'

# cycle: Restarts the ntfy listener using the standard log path
cycle() {
    echo "?? Cycling Listener..."
    pkill -f ntfy_listener.sh
    sleep 1
    # Fixed path to match your ~/scripts/logs/ directory
    nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &
    echo "? Listener restarted. Logging to ~/scripts/logs/ntfy.log"
}

# --- BASH INTEGRATION ---
if ! grep -q "scripts/aliases.sh" ~/.bashrc; then
    echo "source /home/pi/scripts/aliases.sh" >> ~/.bashrc
fi