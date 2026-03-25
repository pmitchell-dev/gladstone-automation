#!/bin/bash
# Agnostic Rebuild - Strictly contained in ~/scripts
SCRIPT_DIR="$HOME/scripts"

echo "🚀 Starting Pi 5 Rebuild for $HOSTNAME..."

# 1. CLEANUP: Delete the "escaped" files from the Home folder
rm -f ~/*.sh ~/*-help.txt

# 2. DASHBOARD: Point .bashrc to the correct folder
sed -i '/pi-dashboard.sh/d' ~/.bashrc
echo "[[ -f $SCRIPT_DIR/pi-dashboard.sh ]] && bash $SCRIPT_DIR/pi-dashboard.sh" >> ~/.bashrc

# 3. CRONTAB: Build the Agnostic Crontab pointing to SCRIPT_DIR
cat << CRON > $SCRIPT_DIR/temp_cron
0 0,8,12,16,20 * * * $SCRIPT_DIR/get_printer_status.sh
1 0,8,12,16,20 * * * $SCRIPT_DIR/printer_alert.sh
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
0 12 * * * curl -d "System Heartbeat: \$HOSTNAME is Online 💓" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
@reboot $SCRIPT_DIR/ntfy_listener.sh > \$HOME/ntfy.log 2>&1 &
CRON

# 4. APPLY
crontab $SCRIPT_DIR/temp_cron
rm $SCRIPT_DIR/temp_cron

echo "✅ Rebuild complete. Home directory is now clean."
