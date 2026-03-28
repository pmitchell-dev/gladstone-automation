#!/bin/bash
# ==========================================================
# GLADSTONE MODE-AWARE UPDATE (pi_update.sh)
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
MODE=$(cat ~/.gladstone_mode 2>/dev/null || echo "unknown")

cd $SCRIPT_DIR || exit

echo "?? [$HOSTNAME] Pulling updates from GitHub..."
git pull origin main

# Standard Permissions Fix
chmod +x *.sh

# MODE-SPECIFIC REFRESH
if [ "$MODE" == "ntfy" ]; then
    echo "???  Refreshing Communication Hub Services..."
    # Only the Hub needs to cycle the listener and watchdog
    pkill -f ntfy_listener.sh
    nohup /bin/bash $SCRIPT_DIR/ntfy_listener.sh > $SCRIPT_DIR/logs/ntfy.log 2>&1 &
    bash $SCRIPT_DIR/pi_services_manager.sh
    
elif [ "$MODE" == "webhost" ]; then
    echo "?? Refreshing Webhost Node..."
    # Webhost might only need to restart a specific web service or heartbeat
    # nohup python3 web_app.py & 
fi

echo "? [$HOSTNAME] Update Complete ($MODE mode)."