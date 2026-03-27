#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 GITHUB PULL & REFRESH
# ==========================================================
# PURPOSE:
# Pulls the latest script updates from the GitHub repository 
# and automatically refreshes the Bash environment to apply
# new aliases or configuration changes.
#
# LOGIC:
# 1. Navigates to the local /scripts/ directory.
# 2. Pulls updates from the 'main' branch on GitHub.
# 3. If successful, reloads ~/.bashrc so the user's active
#    terminal session is updated with the latest aliases.
# ==========================================================

# --- CONFIGURATION ---
# The target directory for all Gladstone automation scripts
SCRIPT_DIR="/home/pi/scripts"

echo "📥 Checking GitHub for updates..."

# 1. DIRECTORY NAVIGATION
# Ensures the script is running inside the local Git repository
cd "$SCRIPT_DIR" || exit

# 2. VERSION CONTROL PULL
# Attempts to download and merge the latest code from the 'main' branch
if git pull origin main; then
    echo "✅ Scripts updated successfully."

    # 3. ENVIRONMENT REFRESH
    # 'source' re-reads the bash configuration file immediately.
    # This ensures any new aliases added to aliases.sh (which is sourced 
    # in .bashrc) are available to the user right now.
    source ~/.bashrc
    echo "🔄 Environment refreshed. Your new aliases are ready."
else
    # ERROR HANDLING
    # Triggers if there is no internet or if there are "local conflicts"
    # (meaning a file was edited on the Pi and on GitHub simultaneously).
    echo "❌ Update failed. Check for local conflicts or connection."
fi
