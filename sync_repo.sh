#!/bin/bash
# Universal Git Sync Script
SCRIPT_DIR="$HOME/scripts"
cd "$SCRIPT_DIR" || exit

echo "🔄 Starting Cloud Sync..."

# 1. Stage all changes (new, modified, and deleted)
git add -A

# 2. Commit changes (|| true prevents the script from stopping if nothing changed)
git commit -m "Auto-sync $(date)" || echo "ℹ️ No changes to commit."

# 3. Pull latest from GitHub (Rebase keeps the history clean)
echo "📥 Pulling updates from GitHub..."
git pull --rebase

# 4. Push everything to GitHub
echo "📤 Pushing updates to GitHub..."
git push

echo "✅ Sync Complete! Your scripts are backed up."
