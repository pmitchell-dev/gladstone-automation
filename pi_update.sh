#!/bin/bash
# ==========================================================
# GLADSTONE MODE-AWARE UPDATE (pi_update.sh)
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
MODE=$(cat ~/.gladstone_mode 2>/dev/null || echo "unknown")

SCRIPT_PATH=$(realpath "$0")
cd "$SCRIPT_DIR" || exit

# ANSI Color Formatting
CYAN='\033[0;36m'
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${BOLD_CYAN}🔄 [$HOSTNAME] Pulling script updates from GitHub...${RESET}"

# Ensure origin remote is set to pmitchell-dev repo
git remote set-url origin https://github.com/pmitchell-dev/pi5-scripts.git 2>/dev/null || true

# Auto-reset any local unstaged changes to ensure clean rebase
git checkout -- . 2>/dev/null

BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
git pull --rebase origin main 2>/dev/null || git pull --rebase origin master 2>/dev/null || git pull --rebase
AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${BOLD_YELLOW}🚀 NEW SCRIPT UPDATES DETECTED & PULLED [pi5-scripts]${RESET}"
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${CYAN} Repository:${RESET}   https://github.com/pmitchell-dev/pi5-scripts"
    echo -e "${CYAN} Commit Range:${RESET} ${BEFORE_PULL:~0:7}..${AFTER_PULL:~0:7}"
    echo -e "${CYAN} New Commits:${RESET}"
    git log --oneline -n 5 "$BEFORE_PULL..$AFTER_PULL" | sed 's/^/   • /'
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${BOLD_CYAN}🔄 Scripts updated. Re-executing update script...${RESET}"
    exec /bin/bash "$SCRIPT_PATH" "$@"
else
    echo -e "  ${CYAN}[pi5-scripts]${RESET} Already up to date (no new changes found)."
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