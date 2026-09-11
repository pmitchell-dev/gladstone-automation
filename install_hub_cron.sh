#!/bin/bash
# ==========================================================
# HUB (PI 5) CRONTAB INSTALLER
# ==========================================================

CRON_TMP=$(mktemp)
crontab -l > "$CRON_TMP" 2>/dev/null || true

HUB_DIR="$HOME/gladstone-automation"

# Remove old entries to prevent duplicates
sed -i '/get_printer_status.sh/d' "$CRON_TMP"
sed -i '/printer_alert.sh/d' "$CRON_TMP"
sed -i '/net_speed.sh/d' "$CRON_TMP"
sed -i '/backup.sh --mode ntfy/d' "$CRON_TMP"
sed -i '/services_manager.sh/d' "$CRON_TMP"
sed -i '/Hub Master Crontab/d' "$CRON_TMP"

cat << EOF >> "$CRON_TMP"
# Hub Master Crontab
0 0,8,12,16,20 * * * $HUB_DIR/get_printer_status.sh
1 0,8,12,16,20 * * * $HUB_DIR/printer_alert.sh
0 */6 * * * $HUB_DIR/net_speed.sh
0 0 * * * $HUB_DIR/backup.sh --mode ntfy
*/5 * * * * $HUB_DIR/services_manager.sh
EOF

crontab "$CRON_TMP"
rm -f "$CRON_TMP"
echo "✅ Hub crontab installed successfully."
