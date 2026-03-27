#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 CLOUD SYNC & DASHBOARD LOGGING
# ==========================================================
# PURPOSE:
# Performs an automated GitHub backup and maintains a local 
# log file to track the last successful synchronization.
#
# LOGIC:
# 1. Navigates to the scripts directory.
# 2. Stages, commits, and pushes all local changes to GitHub.
# 3. If successful, writes a timestamp to /home/pi/last_sync.log.
# 4. If failed, alerts the user via the terminal/logs.
# ==========================================================

# --- CONFIGURATION ---
# The central repository for all Gladstone automation
SCRIPT_DIR="/home/pi/scripts"

echo "🔄 Starting Cloud Sync to GitHub..."

# 1. DIRECTORY NAVIGATION
# Ensures we are inside the Git repository before running commands.
cd "$SCRIPT_DIR" || exit

# 2. GIT SYNCHRONIZATION
# git add .: Stages all new and modified files.
# git commit: Saves the snapshot with a readable date/time string.
# git push: Uploads the local repository to the 'main' branch on GitHub.
git add .
git commit -m "Automated Sync: $(date '+%Y-%m-%d %H:%M')"
git push origin main

# 3. DASHBOARD LOGGING & ERROR HANDLING
# $? checks the exit status of the 'git push' command.
# 0 = Success | Any other number = Failure.
if [ $? -eq 0 ]; then
    # Create/Overwrite the heartbeat file with the current timestamp
    date "+%Y-%m-%d %H:%M" > /home/pi/last_sync.log
    echo "✅ Sync Successful. Dashboard updated."
else
    # Alerts the user if there is a credential issue or internet outage
    echo "❌ Sync Failed. Check your GitHub connection or SSH keys."
fi
