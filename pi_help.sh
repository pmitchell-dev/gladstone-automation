#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

HELP_MSG="🛠️ $HOSTNAME Bot Commands:
--------------------------
🏥 health
   Get Printer Toner & Status

   Ex: 'flight WN102'

📊 flight /status
   Check active trackers

🛑 flight /stop
   Kill all tracking
--------------------------"

# Send the Guide
curl -s -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null

# Immediately follow up with the actual Health Check
bash /home/pi/scripts/printer_health.sh
