#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 OFFICIAL ALIASES & UTILITIES (v1.6)
# ==========================================================

SCRIPT_DIR="$HOME/scripts"

# --- DASHBOARD & MONITORING ---
if [ -f "$HOME/.gladstone_mode" ] && grep -q "webhost" "$HOME/.gladstone_mode"; then
    alias db="bash $SCRIPT_DIR/webhost-dashboard.sh"
    alias dashboard="bash $SCRIPT_DIR/webhost-dashboard.sh"
else
    alias db="bash $SCRIPT_DIR/pi-dashboard.sh"
    alias dashboard="bash $SCRIPT_DIR/pi-dashboard.sh"
fi

# --- MAINTENANCE & RECOVERY ---
alias sync="bash $SCRIPT_DIR/pi_sync.sh"
alias rebuild="bash $SCRIPT_DIR/pi_rebuild.sh"
alias update="bash $SCRIPT_DIR/pi_update.sh"
alias reinstall="bash $SCRIPT_DIR/install.sh"
alias refresh='source ~/.bashrc && echo "? Environment refreshed."'

# --- COMMUNICATION & SERVICES ---
# Shorthand for the relay script
alias relay="bash $SCRIPT_DIR/relay.sh"

# cycle: Restarts the ntfy listener using the standard log path
cycle() {
    echo "?? Cycling Listener..."
    pkill -f ntfy_listener.sh
    sleep 1
    nohup /bin/bash "$SCRIPT_DIR/ntfy_listener.sh" > "$SCRIPT_DIR/logs/ntfy.log" 2>&1 &
    echo "? Listener restarted. Logging to $SCRIPT_DIR/logs/ntfy.log"
}

# --- BASH INTEGRATION ---
if ! grep -q "scripts/aliases.sh" ~/.bashrc; then
    echo 'source "$HOME/scripts/aliases.sh"' >> ~/.bashrc
fi