#!/bin/bash
# Gladstone Pi 5 Cloud Sync & Logging
SCRIPT_DIR="/home/pi/scripts"

echo "🔄 Starting Cloud Sync to GitHub..."

# 1. Navigate to your scripts folder
cd "$SCRIPT_DIR" || exit

# 2. Perform the Git Sync
# We'll add all changes, commit with a timestamp, and push
git add .
git commit -m "Automated Sync: $(date '+%Y-%m-%d %H:%M')"
git push origin main

# 3. Update the Dashboard Log (The important part!)
if [ $? -eq 0 ]; then
    date "+%Y-%m-%d %H:%M" > /home/pi/last_sync.log
    echo "✅ Sync Successful. Dashboard updated."
else
    echo "❌ Sync Failed. Check your GitHub connection."
fi
