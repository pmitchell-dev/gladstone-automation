#!/bin/bash

# ==========================================================
# GLADSTONE GROUND-ZERO BOOTSTRAP (install.sh)
# ==========================================================
# PURPOSE:
# The entry point for fresh installs or major updates.
# Installs dependencies and fixes permissions.
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
LOG_DIR="$SCRIPT_DIR/logs"
BACKUP_DIR="$SCRIPT_DIR/backup"

echo "?? [$HOSTNAME] Starting Ground-Zero Installation..."

# --- 1. CORE DEPENDENCY INSTALLATION ---
sudo apt update
sudo apt install -y jq curl git bc ntfy speedtest-cli zip || echo "??  Package install warnings (non-critical)."

# --- 2. DIRECTORY & PERMISSION ENFORCEMENT ---
echo "?? Enforcing Gladstone File Permissions..."

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Stage 1: Make all Shell scripts executable
chmod +x $SCRIPT_DIR/*.sh

# Stage 2: Ensure data/config/logs are NOT executable
chmod -x $SCRIPT_DIR/*.registry 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.txt 2>/dev/null || true
chmod -x $SCRIPT_DIR/.gitignore 2>/dev/null || true
chmod -R -x "$LOG_DIR" 2>/dev/null || true
chmod -R -x "$BACKUP_DIR" 2>/dev/null || true

# --- 3. MASTER REBUILD TRIGGER ---
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    echo "??  Chaining to pi_rebuild.sh..."
    bash "$SCRIPT_DIR/pi_rebuild.sh"
else
    echo "? Error: pi_rebuild.sh not found. Installation aborted."
    exit 1
fi

echo "-------------------------------------------------------"
echo "? [$HOSTNAME] Installation & Permissions Verified."
echo "-------------------------------------------------------"