#!/bin/bash

# ==========================================================
# GLADSTONE NTFY COMMAND GUIDE (HELP SYSTEM)
# ==========================================================
# PURPOSE:
# Sends a formatted menu of available remote commands to the
# user's ntfy topic. Acts as the "UI" for the Pi 5 bot.
# ==========================================================

# --- CONFIGURATION ---
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

# --- THE HELP MENU ---
# Using $HOSTNAME makes the message dynamic (e.g., "Gladstone-hub Bot")
HELP_MSG="🛠️ $HOSTNAME Bot Commands:
--------------------------
🏥 health
   Get Printer Toner & Status

   Ex: 'flight WN102'

📊 flight /status
   Check active trackers

🛑 flight /stop
   Kill all tracking
--------------------------"

# --- EXECUTION ---
# 1. Send the text-based Guide to ntfy
curl -s -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null

# 2. PROACTIVE UPDATE:
# Immediately follow up by running the actual Printer Health script.
# This ensures the user sees live data right after the help menu.
bash /home/gladstone/scripts/printer_health.sh
