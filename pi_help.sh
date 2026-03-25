#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

HELP_MSG="🛠️ $HOSTNAME Bot Commands:
--------------------------
✈️  Flight [ID]
   Ex: 'Flight DL1660'

🏁 Flight [ID] to [DEST]
   Ex: 'Flight DL1660 to MSP'

📊 Flight /status
   Check if a tracker is running

🛑 Flight /stop
   Kill all active tracking

🔄 rebuild
   Restore system & crontab
--------------------------"

curl -s -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null
