#!/bin/bash
# Gladstone GitHub Pull & Refresh
SCRIPT_DIR="/home/pi/scripts"

echo "📥 Checking GitHub for updates..."
cd "$SCRIPT_DIR" || exit

# 1. Pull changes
if git pull origin main; then
    echo "✅ Scripts updated successfully."
    # 2. Refresh the environment immediately
    source ~/.bashrc
    echo "🔄 Environment refreshed."
else
    echo "❌ Update failed. Check for local conflicts or connection."
fi
