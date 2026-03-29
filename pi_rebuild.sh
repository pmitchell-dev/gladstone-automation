#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v2.0 - Auto-Sync)
# ==========================================================
MODE=$1 
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

# --- 1. HUB MODE (Raspberry Pi Only) ---
if [ "$MODE" == "--ntfy" ]; then
    echo "??? Applying Hub Crontab..."
    MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -

# --- 2. WEBHOST MODE (Laptop Only) ---
elif [ "$MODE" == "--webhost" ]; then
    echo "?? Synchronizing Webhost Services..."
    
    if [ -d "/home/pi/homebox" ]; then
        echo "?? Pulling latest code from GitHub..."
        cd /home/pi/homebox
        git pull origin main
        
        echo "?? Rebuilding local Homebox-Custom image..."
        # Rebuilds from your modified source code
        docker build -t homebox-custom:latest .
        # Restarts the container with the new build
        docker compose up -d
        echo "? Deployment Successful."
    fi

    # Webhost Maintenance Crontab
    WEB_CRON="0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -
fi

echo "? [$HOSTNAME] Rebuild Complete."