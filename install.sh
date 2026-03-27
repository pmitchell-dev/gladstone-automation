#!/bin/bash

# ==========================================================
# GLADSTONE GROUND-ZERO BOOTSTRAP (install.sh)
# ==========================================================
# PURPOSE: Installs dependencies and enforces permissions.
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
LOG_DIR="$SCRIPT_DIR/logs"

echo "?? Starting Ground-Zero Installation for $HOSTNAME..."

# --- 1. CORE DEPENDENCY INSTALLATION ---
sudo apt update
sudo apt install -y jq curl git bc ntfy speedtest-cli || echo "?? Some packages failed."

# --- 2. PERMISSION ENFORCEMENT ---
echo "?? Enforcing Gladstone File Permissions..."

# Ensure directories exist
mkdir -p $LOG_DIR

# Stage 1: Make all Shell scripts executable
chmod +x $SCRIPT_DIR/*.sh

# Stage 2: Ensure data/config/logs are NOT executable
chmod -x $SCRIPT_DIR/*.registry 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.txt 2>/dev/null || true
chmod -R -x $LOG_DIR/*.log 2>/dev/null || true

# --- 3. MASTER REBUILD TRIGGER ---
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    echo "??  Handing off to pi_rebuild.sh..."
    bash $SCRIPT_DIR/pi_rebuild.sh
else
    echo "? Error: pi_rebuild.sh not found."
    exit 1
fi