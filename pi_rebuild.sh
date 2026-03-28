#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (pi_rebuild.sh)
# ==========================================================

MODE=$1 # --ntfy or --webhost
mkdir -p /home/pi/scripts/logs
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

# --- 1. CORE SETUP ---
mkdir -p /home/pi/scripts/backup
bash /home/pi/scripts/aliases.sh

# --- 2. MODE: NTFY (Central Comm Hub) ---
if [ "$MODE" == "--ntfy" ]; then
    echo "???  Configuring Gladstone Communication Hub..."
    
    # Master Crontab for the Hub
    MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 12 * * * curl -d \"[$HOSTNAME] Hub Heartbeat: Active\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"

    echo "$MASTER_CRON" | crontab -
    
    # Restart the Hub Listener
    pkill -f ntfy_listener.sh
    nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &

# --- 3. MODE: WEBHOST (Target Server) ---
elif [ "$MODE" == "--webhost" ]; then
    echo "?? Configuring Webhost Node..."
    # Webhosts only need a heartbeat and a simple listener, not the printer/speed scripts
    WEB_CRON="0 12 * * * curl -d \"[$HOSTNAME] Webhost: Active\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
    echo "$WEB_CRON" | crontab -
fi

echo "? [$HOSTNAME] Rebuild Complete."