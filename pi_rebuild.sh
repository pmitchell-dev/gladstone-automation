#!/bin/bash
SCRIPT_DIR="$HOME/scripts"

echo "🚀 Starting Rebuild for $HOSTNAME..."

# 1. CLEANUP: Clear stray files
rm -f ~/*.sh ~/*-help.txt

# 2. BASHRC: Link the Dashboard AND the Master Aliases
sed -i '/pi-dashboard.sh/d' ~/.bashrc
sed -i '/aliases.sh/d' ~/.bashrc
echo "[[ -f $SCRIPT_DIR/pi-dashboard.sh ]] && bash $SCRIPT_DIR/pi-dashboard.sh" >> ~/.bashrc
echo "[[ -f $SCRIPT_DIR/aliases.sh ]] && source $SCRIPT_DIR/aliases.sh" >> ~/.bashrc

# 3. CRONTAB: Standard logic
cat << CRON > $SCRIPT_DIR/temp_cron
0 0,8,12,16,20 * * * $SCRIPT_DIR/get_printer_status.sh
1 0,8,12,16,20 * * * $SCRIPT_DIR/printer_alert.sh
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
0 12 * * * curl -d "System Heartbeat: \$HOSTNAME is Online 💓" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
@reboot $SCRIPT_DIR/ntfy_listener.sh > \$HOME/ntfy.log 2>&1 &
CRON
crontab $SCRIPT_DIR/temp_cron
rm $SCRIPT_DIR/temp_cron

# 4. NOTIFY
curl -d "✅ $HOSTNAME: System Rebuild Complete." ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
echo "✅ Rebuild complete. Master Aliases are now linked."
mkdir -p /home/pi/printer_data
chmod +x /home/pi/scripts/*.sh
