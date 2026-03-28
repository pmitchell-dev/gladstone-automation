#!/bin/bash

# ==========================================================
# GLADSTONE FULL SYSTEM PROVISIONER (pi_rebuild.sh)
# ==========================================================
# MASTER CRONTAB (IDEMPOTENT OVERWRITE)
# ==========================================================

mkdir -p /home/pi/scripts/logs
mkdir -p /home/pi/scripts/backup
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Resetting Crontab to Master Standard..."

MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 12 * * * curl -d \"[$HOSTNAME] Daily Heartbeat: Healthy\" ntfy.sh/patrick_mitch_pi5_x9k2v_alerts
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"

echo "$MASTER_CRON" | crontab -
echo "? Crontab synchronized."

# Ensure retry file is clean on rebuild
rm -f /tmp/service_retries

echo "? [$HOSTNAME] Rebuild Complete."