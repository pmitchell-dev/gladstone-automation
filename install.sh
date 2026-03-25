#!/bin/bash
# RPi5 Bootstrap - The "Agnostic" Recovery Script
SCRIPT_DIR="$HOME/scripts"

echo "📥 Starting Ground-Zero Installation for $HOSTNAME..."

# 1. Attempt to install core dependencies
sudo apt update
sudo apt install -y jq curl git bc ntfy || sudo apt install -y ntfy-client || echo "⚠️ ntfy package not found, manual install may be needed."

# 2. Set permissions
chmod +x $SCRIPT_DIR/*.sh

# 3. Run the master rebuild
bash $SCRIPT_DIR/pi_rebuild.sh

# 4. Final Summary and Manual Instructions
echo ""
echo "-------------------------------------------------------"
echo "✅ SYSTEM RESTORED ON $HOSTNAME"
echo "-------------------------------------------------------"
echo "📦 REQUIRED DEPENDENCIES:"
echo "   - git, curl, jq, bc, ntfy"
echo ""
echo "🛠️  MANUAL COMMANDS YOU CAN RUN NOW:"
echo "   1. source ~/.bashrc          -> Load your Dashboard and Aliases"
echo "   2. sync                     -> Push any local changes to GitHub"
echo "   3. bash ~/cleanup_test.sh   -> Wipe this VM/Server for a fresh test"
echo "   4. ntfy publish patrick_mitch_pi5_x9k2v_alerts 'Test' -> Test Phone Alerts"
echo "-------------------------------------------------------"
