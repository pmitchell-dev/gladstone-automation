#!/bin/bash

# ==========================================================
# GLADSTONE FULL SYSTEM PROVISIONER (pi_rebuild.sh)
# ==========================================================
# PURPOSE: Configures directories, schedules tasks, and 
# resets the crontab to the Gladstone Master Standard.
# ==========================================================

# Log the rebuild process to the new logs folder
mkdir -p /home/pi/scripts/logs
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "??? Rebuilding Gladstone Environment..."

# --- 1. ARCHITECTURE-SPECIFIC INSTALLATION ---
if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "?? x86 detected. Installing laptop support tools..."
    sudo apt update && sudo apt install -y lm-sensors htop jq curl git
    sudo sensors-detect --auto > /dev/null
else
    echo "?? Raspberry Pi detected. Installing Pi support tools..."
    sudo apt update && sudo apt install -y jq curl git
fi

# --- 2. DIRECTORY STRUCTURE ---
mkdir -p /home/pi/scripts/logs
mkdir -p /home/pi/printer_data

# --- 3. ALIAS & REGISTRY ---
bash /home/pi/scripts/aliases.sh

if [ ! -f "/home/pi/scripts/services.registry" ]; then
    echo "ntfy_listener.sh|8080|Main ntfy command listener" > /home/pi/scripts/services.registry
fi

# --- 4. CRON SCHEDULING ---
echo "?? Updating Crontab schedules..."
(crontab -l 2>/dev/null | grep -vE "printer|manager|heartbeat|ntfy_listener|net_speed"; 
 echo "0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh"
 echo "1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh"
 echo "0 */6 * * * /home/pi/scripts/net_speed.sh"
 echo "*/5 * * * * /home/pi/scripts/pi_services_manager.sh"
 echo "0 12 * * * curl -d \"Pi 5 Daily Heartbeat: Healthy\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"
 echo "@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
) | crontab -

# --- 5. SERVICE INITIALIZATION ---
pkill -f ntfy_listener.sh
nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &

echo "? Rebuild Complete. Logs moved to ~/scripts/logs/"