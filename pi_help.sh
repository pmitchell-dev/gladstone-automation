#!/bin/bash
# Remote-Only Guide
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

HELP_MSG="🛠️ $HOSTNAME Automation Guide:
--------------------------
✈️  Flight [ID]
   Ex: 'Flight DL1660'

🏁 Flight [ID] to [DEST]
   Ex: 'Flight DL1660 to MSP'

🔄 Rebuild
   Restores system, cron, & dash

📂 Sync
   Backs up all scripts to GitHub

🧹 Cleanup
   (VM Only) Wipes the test environment
--------------------------
Check logs: tail -f ~/ntfy.log"

# Push to phone
curl -s -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null
