#!/bin/bash

# ==========================================================
# GLADSTONE SYSTEM CLEANUP (DEEP CLEAN)
# ==========================================================
# PURPOSE:
# Completely wipes the Gladstone automation environment.
# Use this to reset a VM or Pi before testing a fresh 
# installation from GitHub.
# ==========================================================

echo "🧹 Starting Deep Clean of Gladstone Environment..."

# --- 1. PROCESS TERMINATION ---
# Kills any background listeners or active flight trackers
# to ensure files aren't "in use" during deletion.
pkill -f ntfy_listener.sh
pkill -f track_flight.sh

# --- 2. FILE SYSTEM PURGE ---
# rm -rf: Forcefully removes the entire scripts directory.
# rm -f: Deletes specific stray logs, help files, and shell scripts 
# from the root of the home directory (~).
echo "🗑️  Wiping scripts folder and stray logs..."
rm -rf ~/scripts
rm -f ~/*.sh ~/*-help.txt ~/ntfy.log ~/services_manager.log

# --- 3. ENVIRONMENT RESET ---
# crontab -r: Completely deletes the user's crontab (removes all scheduled tasks).
echo "📅 Resetting Crontab..."
crontab -r

# --- 4. BASHRC CLEANUP ---
# 'sed -i ... /d': Searches your .bashrc and deletes lines containing 
# specific keywords. This un-links the dashboard and sync aliases 
# so your terminal returns to a standard state.
echo "🐚 Cleaning up .bashrc aliases..."
sed -i '/pi-dashboard.sh/d' ~/.bashrc
sed -i '/alias sync=/d' ~/.bashrc
# Also removing the source line if it exists
sed -i '/scripts\/aliases.sh/d' ~/.bashrc

echo "✨ VM is now 'Naked'. All Gladstone files and automations removed."
