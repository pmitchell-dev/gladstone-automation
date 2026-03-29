#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v1.9)
# ==========================================================
MODE=$1 
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

if [ "$MODE" == "--ntfy" ]; then
    # HUB CRONTAB
    MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -

elif [ "$MODE" == "--webhost" ]; then
    echo "?? Provisioning Webhost Services..."
    
    # BUILD HOMEBOX FROM SOURCE
    if [ -d "/home/pi/homebox" ]; then
        echo "?? Building local Homebox image..."
        cd /home/pi/homebox
        docker build -t homebox-custom:latest .
        docker compose up -d
    fi

    # WEBHOST CRONTAB
    WEB_CRON="0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -
fi

echo "? Rebuild Complete."