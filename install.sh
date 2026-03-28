#!/bin/bash

# ==========================================================
# GLADSTONE GROUND-ZERO BOOTSTRAP (install.sh)
# ==========================================================
# PURPOSE:
# Installs dependencies and enforces strict permissions/ownership.
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
LOG_DIR="$SCRIPT_DIR/logs"
BACKUP_DIR="$SCRIPT_DIR/backup"

echo "?? [$HOSTNAME] Starting Ground-Zero Installation..."

# --- 1. CORE DEPENDENCY INSTALLATION ---
sudo apt update
sudo apt install -y jq curl git bc ntfy speedtest-cli zip || echo "??  Package install warnings."

# --- 2. DIRECTORY & OWNERSHIP ENFORCEMENT ---
echo "?? Enforcing Gladstone File Permissions & Ownership..."

# Ensure directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Ensure the 'pi' user owns everything in the scripts folder
# This prevents the "Permission Denied" error on logs
sudo chown -R $USER:$USER "$SCRIPT_DIR"

# Stage 1: Make all Shell scripts executable
chmod +x $SCRIPT_DIR/*.sh

# Stage 2: Ensure non-executables and data folders
chmod -x $SCRIPT_DIR/*.registry 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.txt 2>/dev/null || true
chmod -x $SCRIPT_DIR/.gitignore 2>/dev/null || true

# Set directory permissions (775 allows group writing)
chmod 775 "$LOG_DIR"
chmod 775 "$BACKUP_DIR"

# Ensure existing log files are writable
chmod 664 "$LOG_DIR"/*.log 2>/dev/null || true

# --- 3. MASTER REBUILD TRIGGER ---
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    echo "??  Chaining to pi_rebuild.sh..."
    bash "$SCRIPT_DIR/pi_rebuild.sh"
else
    echo "? Error: pi_rebuild.sh not found."
    exit 1
fi

echo "-------------------------------------------------------"
echo "? [$HOSTNAME] Installation & Permissions Verified."
echo "-------------------------------------------------------"