#!/bin/bash

# ==========================================================
# GLADSTONE GROUND-ZERO BOOTSTRAP (install.sh)
# ==========================================================
# PURPOSE:
# The "Agnostic" recovery entry point. It installs core 
# Linux dependencies, enforces strict file permissions,
# and kicks off the master rebuild process.
# ==========================================================

# --- CONFIGURATION ---
SCRIPT_DIR="/home/pi/scripts"

echo "?? Starting Ground-Zero Installation for $HOSTNAME..."

# --- 1. CORE DEPENDENCY INSTALLATION ---
# speedtest-cli added for network monitoring
sudo apt update
sudo apt install -y jq curl git bc ntfy speedtest-cli || sudo apt install -y ntfy-client || echo "?? ntfy package not found, manual install may be needed."

# --- 2. PERMISSION ENFORCEMENT ---
echo "?? Enforcing Gladstone File Permissions..."

# Stage 1: Make all Shell scripts executable
chmod +x $SCRIPT_DIR/*.sh

# Stage 2: Ensure data/config/text files are NOT executable
chmod -x $SCRIPT_DIR/*.registry 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.txt 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.log 2>/dev/null || true

# --- 3. MASTER REBUILD TRIGGER ---
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    echo "??  Handing off to pi_rebuild.sh..."
    bash $SCRIPT_DIR/pi_rebuild.sh
else
    echo "? Error: pi_rebuild.sh not found. Cannot complete environment setup."
    exit 1
fi

# --- 4. FINAL SUMMARY & POST-INSTALL GUIDE ---
echo ""
echo "-------------------------------------------------------"
echo "? SYSTEM RESTORED ON $HOSTNAME"
echo "-------------------------------------------------------"
echo "???  MANUAL COMMANDS TO FINALIZE:"
echo "   1. source ~/.bashrc           -> Load your Dashboard and Aliases"
echo "   2. db                         -> Verify system vitals and Printer"
echo "   3. sync                       -> Ensure local changes match GitHub"
echo "-------------------------------------------------------"