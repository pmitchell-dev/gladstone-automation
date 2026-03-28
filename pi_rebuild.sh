#!/bin/bash

# ==========================================================
# GLADSTONE FULL SYSTEM PROVISIONER (pi_rebuild.sh)
# ==========================================================

# Log the rebuild process
mkdir -p /home/pi/scripts/logs
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "??? Rebuilding Gladstone Environment..."

# --- 1. ARCHITECTURE-SPECIFIC INSTALLATION ---
if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "?? x86 detected. Installing laptop support tools..."
    sudo apt update && sudo apt install -y lm-sensors htop jq curl git zip
else
    echo "?? Raspberry Pi detected. Installing Pi support tools..."
    sudo apt update && sudo apt install -y jq curl git zip
fi

# --- 2. DIRECTORY STRUCTURE ---
mkdir -p /home/pi/scripts/logs
mkdir -p /home/pi/scripts/backup
mkdir -p /home/pi/printer_data

# --- 3. ALIAS & REGISTRY ---
bash /home/pi/scripts/aliases.sh

# --- 4. CRON SCHEDULING (Updated Heartbeat with Hostname) ---
echo "?? Updating Crontab schedules..."
(crontab -l 2>/dev/null | grep -vE "printer|manager|heartbeat|ntfy_listener|net_speed|pi_backup"; 
 echo "0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh"
 echo "1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh"
 echo "0 */6 * * * /home/pi/scripts/net_speed.sh"
 echo "0 0 * * * /home/pi/scripts/pi_backup.sh"
 echo "*/5 * * * * /home/pi/scripts/pi_services_manager.sh"
 echo "0 12 * * * curl -d \"[$HOSTNAME] Daily Heartbeat: Healthy\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"
 echo "@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
) | crontab -

# --- 5. SERVICE INITIALIZATION ---
pkill -f ntfy_listener.sh
nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &

echo "? Rebuild Complete."