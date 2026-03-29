#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v1.6)
# ==========================================================
MODE=$1 
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

if [ "$MODE" == "--ntfy" ]; then
    # HUB CRONTAB (Heavy Monitoring)
    MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -
    pkill -f ntfy_listener.sh
    nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &

elif [ "$MODE" == "--webhost" ]; then
    # WEBHOST CRONTAB (Lean & Clean)
    # Adds a weekly Docker cleanup to prevent storage bloat
    WEB_CRON="0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes
0 12 * * * curl -d \"[$HOSTNAME] Webhost Heartbeat: Active\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"
    echo "$WEB_CRON" | crontab -
fi

echo "? [$HOSTNAME] Rebuild Complete."