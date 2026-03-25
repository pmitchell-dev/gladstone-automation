#!/bin/bash
# RPi5 Disaster Recovery - Master Rebuild Script

echo "🚀 Starting Pi 5 Rebuild..."

# 1. Recreate scripts from current state
cat << 'INNER' > /home/pi/ntfy_listener.sh
$(cat /home/pi/ntfy_listener.sh)
INNER

cat << 'INNER' > /home/pi/pi-dashboard.sh
$(cat /home/pi/pi-dashboard.sh)
INNER

cat << 'INNER' > /home/pi/track_flight.sh
$(cat /home/pi/track_flight.sh)
INNER

cat << 'INNER' > /home/pi/pi_services_manager.sh
$(cat /home/pi/pi_services_manager.sh)
INNER

chmod +x /home/pi/*.sh

# 2. Rebuild the Crontab
(
  echo "@reboot /home/pi/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &"
  echo "*/5 * * * * /home/pi/pi_services_manager.sh"
  echo "0 12 * * * curl -d 'Pi 5 Daily Heartbeat: System Online 💓' ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"
) | crontab -

echo "✅ Rebuild script updated."
