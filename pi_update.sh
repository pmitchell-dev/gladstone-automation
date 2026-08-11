#!/bin/bash
# ==========================================================
# GLADSTONE MODE-AWARE UPDATE (pi_update.sh)
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
MODE=$(cat ~/.gladstone_mode 2>/dev/null || echo "unknown")

SCRIPT_PATH=$(realpath "$0")
cd "$SCRIPT_DIR" || exit

echo "🔄 [$HOSTNAME] Pulling updates from GitHub..."

# Auto-reset any local unstaged changes to ensure clean rebase
git checkout -- . 2>/dev/null

BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
git pull --rebase origin main
AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
    echo "🔄 Scripts updated. Re-executing update script..."
    exec /bin/bash "$SCRIPT_PATH" "$@"
fi

# Standard Permissions Fix
chmod +x *.sh

# MODE-SPECIFIC REFRESH
if [ "$MODE" == "ntfy" ]; then
    echo "⚙️  Refreshing Communication Hub Services..."
    # Only the Hub needs to cycle the listener and watchdog
    pkill -f ntfy_listener.sh
    nohup /bin/bash "$SCRIPT_DIR/ntfy_listener.sh" > "$SCRIPT_DIR/logs/ntfy.log" 2>&1 &
    bash "$SCRIPT_DIR/pi_services_manager.sh"
    
elif [ "$MODE" == "webhost" ]; then
    echo "🖥️  Refreshing Webhost Node..."
    # Trigger a rebuild to apply any stack changes
    bash "$SCRIPT_DIR/pi_rebuild.sh" --webhost
fi

echo "✅ [$HOSTNAME] Update Complete ($MODE mode)."