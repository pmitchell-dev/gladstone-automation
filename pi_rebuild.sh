#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v2.0 - Auto-Sync)
# ==========================================================
MODE=$1 
if [ -z "$MODE" ] && [ -f "$HOME/.gladstone_mode" ]; then
    MODE="--$(cat $HOME/.gladstone_mode | xargs)"
fi
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
    
    if [ ! -d "/home/pi/homeasset" ]; then
        echo "?? HomeAsset missing. Cloning repository..."
        git clone https://github.com/legendary034/HomeAsset.git /home/pi/homeasset
        if [ -f "/home/pi/scripts/homeasset-compose.yml" ]; then
            cp "/home/pi/scripts/homeasset-compose.yml" "/home/pi/homeasset/docker-compose.yml"
        fi
    fi

    if [ -d "/home/pi/homeasset" ]; then
        echo "?? Pulling latest HomeAsset code from GitHub..."
        cd /home/pi/homeasset
        git pull
        
        echo "?? Rebuilding local HomeAsset image..."
        # Rebuilds from your modified source code using the compose file
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo "? Warning: No docker-compose.yml found in /home/pi/homeasset"
        fi
        echo "? Deployment Successful."
    fi

    if [ ! -d "/home/pi/hivemind" ]; then
        echo "?? HiveMind missing. Cloning repository..."
        git clone https://github.com/legendary034/HiveMind.git /home/pi/hivemind
        if [ -f "/home/pi/scripts/hivemind-compose.yml" ]; then
            cp "/home/pi/scripts/hivemind-compose.yml" "/home/pi/hivemind/docker-compose.yml"
        fi
    fi

    if [ -d "/home/pi/hivemind" ]; then
        echo "?? Pulling latest HiveMind code from GitHub..."
        cd /home/pi/hivemind
        git pull
        
        echo "?? Rebuilding local HiveMind image..."
        # If a docker-compose.yml is present, it will build and run it
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo "? Warning: No docker-compose.yml found in /home/pi/hivemind"
        fi
        echo "? HiveMind Deployment Check Complete."
    fi

    # Webhost Maintenance Crontab
    WEB_CRON="0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -
fi

echo "? [$HOSTNAME] Rebuild Complete."