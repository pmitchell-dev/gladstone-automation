#!/bin/bash
# Remote-Only Guide for Pi 5 Automation
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

HELP_MSG="🛠️ Pi 5 Remote Commands:
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
Triggered by: $HOSTNAME"

# Send directly to ntfy with no terminal output
curl -s -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null
