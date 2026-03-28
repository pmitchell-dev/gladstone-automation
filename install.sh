#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (install.sh)
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"

# Capture flags
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

if [ -z "$MODE" ]; then
    echo "? Error: No mode specified. Use --ntfy or --webhost."
    exit 1
fi

echo "?? [$HOSTNAME] Starting Installation in $MODE mode..."

# 1. Standard Dependencies
sudo apt update
sudo apt install -y jq curl git bc zip

# 2. Mode-Specific Dependencies
if [ "$MODE" == "ntfy" ]; then
    sudo apt install -y ntfy speedtest-cli
fi

# 3. Ownership & Permissions
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh

# 4. Trigger Rebuild with the Mode Flag
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    bash "$SCRIPT_DIR/pi_rebuild.sh" --$MODE
else
    echo "? Error: pi_rebuild.sh missing."
    exit 1
fi