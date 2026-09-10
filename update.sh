#!/bin/bash
# ==========================================================
# GLADSTONE MODE-AWARE UPDATE (update.sh)
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
git remote set-url origin https://github.com/pmitchell-dev/gladstone-automation.git 2>/dev/null || true

# Abort any stuck rebase from prior failed updates
git rebase --abort 2>/dev/null || true

# Auto-reset any local unstaged changes to ensure clean update
git checkout -- . 2>/dev/null

BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
git fetch origin main 2>/dev/null || git fetch origin 2>/dev/null
git reset --hard origin/main 2>/dev/null || git pull --rebase origin main 2>/dev/null
AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${BOLD_YELLOW}🚀 NEW SCRIPT UPDATES DETECTED & PULLED [gladstone-automation]${RESET}"
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${CYAN} Repository:${RESET}   https://github.com/pmitchell-dev/gladstone-automation"
    echo -e "${CYAN} Commit Range:${RESET} ${BEFORE_PULL:~0:7}..${AFTER_PULL:~0:7}"
    echo -e "${CYAN} New Commits:${RESET}"
    git log --oneline -n 5 "$BEFORE_PULL..$AFTER_PULL" | sed 's/^/   • /'
    echo -e "${BOLD_GREEN}========================================================================${RESET}"
    echo -e "${BOLD_CYAN}🔄 Scripts updated. Re-executing update script...${RESET}"
    exec /bin/bash "$SCRIPT_PATH" "$@"
else
    echo -e "  ${CYAN}[gladstone-automation]${RESET} Already up to date (no new changes found)."
fi

# Standard Permissions Fix
chmod +x *.sh

# MODE-SPECIFIC REFRESH
if [ "$MODE" == "ntfy" ]; then
    echo "⚙️  Refreshing Communication Hub Services & Stacks..."
    # Cycle the command listener, watchdog, and sync container stacks
    pkill -f ntfy_listener.sh
    nohup /bin/bash "$SCRIPT_DIR/ntfy_listener.sh" > "$SCRIPT_DIR/logs/ntfy.log" 2>&1 &
    bash "$SCRIPT_DIR/rebuild.sh" --ntfy
    
elif [ "$MODE" == "webhost" ] || [ -d "$HOME/relayit" ]; then
    echo "🖥️  Refreshing Webhost Node & Application Stacks..."
    # Trigger a rebuild to apply any stack changes
    bash "$SCRIPT_DIR/rebuild.sh" --webhost
fi

if [ "$MODE" == "webhost" ]; then
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
        echo -e "${BOLD_YELLOW}⚠️  RCLONE AUTHENTICATION REQUIRED:${RESET}"
        echo -e "   File ${BOLD_CYAN}~/.config/rclone/rclone.conf${RESET} was not found."
        echo -e "   Run '${BOLD_CYAN}rclone config${RESET}' on the Pi to pair your Google Drive."
    fi
    if [ -f "$HOME/.config/rclone/rclone_photos.env" ] && grep -q "YOUR_REMOTE_FOLDER" "$HOME/.config/rclone/rclone_photos.env" 2>/dev/null; then
        echo -e "${BOLD_YELLOW}⚠️  RCLONE FOLDER SETUP REQUIRED:${RESET}"
        echo -e "   Please edit ${BOLD_CYAN}~/.config/rclone/rclone_photos.env${RESET} to set your Google Drive remote source and backup target path."
    fi
fi

echo "✅ [$HOSTNAME] Update Complete ($MODE mode)."