#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 UNIVERSAL GIT SYNC SCRIPT
# ==========================================================
# PURPOSE:
# Automatically stages, commits, and synchronizes all custom
# scripts with a remote GitHub repository.
#
# LOGIC:
# 1. Navigates to the scripts directory.
# 2. Captures all local changes (adds, edits, deletes).
# 3. Commits changes with a timestamped message.
# 4. Pulls remote updates using rebase to maintain a clean history.
# 5. Pushes the final consolidated state to GitHub.
# ==========================================================

# --- CONFIGURATION ---
# Points to the central folder for all Gladstone automation
SCRIPT_DIR="$HOME/scripts"
cd "$SCRIPT_DIR" || exit

echo "🔄 Starting Cloud Sync for Gladstone Scripts..."

# 1. STAGE CHANGES
# 'git add -A' tracks everything: new files, modified code, and deleted scripts.
git add -A

# 2. LOCAL COMMIT
# Creates a snapshot of the current state.
# '|| echo' ensures the script continues even if there's nothing new to save.
git commit -m "Auto-sync $(date)" || echo "ℹ️ No changes to commit; local repo is already up to date."

# 3. REMOTE PULL (SYNC DOWN)
# --rebase ensures your local changes are applied on top of remote changes,
# preventing unnecessary "Merge branch..." commits in your history.
echo "📥 Pulling updates from GitHub..."
git pull --rebase

# 4. REMOTE PUSH (SYNC UP)
# Uploads all your Gladstone Pi 5 progress to the cloud.
echo "📤 Pushing updates to GitHub..."
git push

echo "✅ Sync Complete! Your scripts are backed up and versioned."
