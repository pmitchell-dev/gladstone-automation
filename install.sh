#!/bin/bash
# RPi5 Bootstrap - The "Agnostic" Recovery Script
SCRIPT_DIR="$HOME/scripts"
echo "📥 Starting Ground-Zero Installation for $HOSTNAME..."
sudo apt update && sudo apt install -y jq curl git bc
chmod +x $SCRIPT_DIR/*.sh
bash $SCRIPT_DIR/pi_rebuild.sh
echo "-----------------------------------------"
echo "✅ SYSTEM RESTORED ON $HOSTNAME"
echo "-----------------------------------------"
