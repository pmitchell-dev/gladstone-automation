#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v2.1 - Auto-Sync)
# ==========================================================
MODE=$1 
if [ -z "$MODE" ] && [ -f "$HOME/.gladstone_mode" ]; then
    MODE="--$(cat $HOME/.gladstone_mode | xargs)"
fi

SCRIPT_DIR="$HOME/scripts"
mkdir -p "$SCRIPT_DIR/logs"
exec > >(tee -a "$SCRIPT_DIR/logs/rebuild.log") 2>&1

# ANSI Color Definitions
CYAN='\033[0;36m'
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${BOLD_CYAN}🔄 [$HOSTNAME] Rebuilding in $MODE mode...${RESET}"

# Ensure the scripts themselves are up to date
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo -e "${BOLD_CYAN}🔄 Updating scripts from GitHub...${RESET}"
    SCRIPT_PATH=$(realpath "$0")
    cd "$SCRIPT_DIR" || exit
    git remote set-url origin https://github.com/pmitchell-dev/pi5-scripts.git 2>/dev/null || true
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
        echo -e "${BOLD_CYAN}🔄 Scripts updated. Re-executing rebuild script...${RESET}"
        exec /bin/bash "$SCRIPT_PATH" "$@"
    else
        echo -e "  ${CYAN}[pi5-scripts]${RESET} Already up to date (no new changes found)."
    fi
fi


# --- 1. HUB MODE (Raspberry Pi Only) ---
if [ "$MODE" == "--ntfy" ]; then
    echo "📝 Applying Hub Crontab..."
    MASTER_CRON="0 0,8,12,16,20 * * * $SCRIPT_DIR/get_printer_status.sh
1 0,8,12,16,20 * * * $SCRIPT_DIR/printer_alert.sh
0 */6 * * * $SCRIPT_DIR/net_speed.sh
0 0 * * * $SCRIPT_DIR/pi_backup.sh --mode ntfy
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
*/15 * * * * $SCRIPT_DIR/cloudflare_ddns.sh
@reboot /bin/bash $SCRIPT_DIR/ntfy_listener.sh > $SCRIPT_DIR/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -

    # Dozzle Agent Stack Sync
    if [ -d "$HOME/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Agent..."
        if [ -f "$SCRIPT_DIR/dozzle-agent-compose.yml" ]; then
            cp "$SCRIPT_DIR/dozzle-agent-compose.yml" "$HOME/dozzle/docker-compose.yml"
        fi
        mkdir -p "$SCRIPT_DIR/logs"
        cd "$HOME/dozzle" && sudo docker compose up -d --remove-orphans
        echo "✅ Dozzle Agent synced on port 7007."
    fi

    # Simple Login Stack Sync
    if [ -d "$HOME/simplelogin" ] || [ -f "$SCRIPT_DIR/simplelogin-compose.yml" ]; then
        echo "📧 Synchronizing Simple Login Stack..."
        SIMPLELOGIN_DIR="$HOME/simplelogin"
        mkdir -p "$SIMPLELOGIN_DIR/data/pgdata" "$SIMPLELOGIN_DIR/data/sl" "$SIMPLELOGIN_DIR/data/upload"
        if [ -f "$SCRIPT_DIR/simplelogin-compose.yml" ]; then
            cp "$SCRIPT_DIR/simplelogin-compose.yml" "$SIMPLELOGIN_DIR/docker-compose.yml"
        fi
        cd "$SIMPLELOGIN_DIR"
        sudo docker compose down --remove-orphans 2>/dev/null || true
        sudo docker compose up -d --remove-orphans
        echo "✅ Simple Login synced at http://simplelogin.localrepo.net:7777 (localrepo.net)"
    fi

# --- 2. WEBHOST MODE (Laptop Only) ---
elif [ "$MODE" == "--webhost" ]; then
    echo "🔄 Synchronizing Webhost Services..."
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Purge legacy Invidious containers & files if present
    INVIDIOUS_CONTAINERS=$(docker ps -a --filter "name=invidious" -q 2>/dev/null)
    if [ -n "$INVIDIOUS_CONTAINERS" ]; then
        echo -e "${BOLD_CYAN}🧹 Stopping and purging legacy Invidious containers...${RESET}"
        docker stop $INVIDIOUS_CONTAINERS 2>/dev/null || true
        docker rm -f $INVIDIOUS_CONTAINERS 2>/dev/null || true
    fi
    if [ -d "$HOME/invidious" ]; then
        rm -rf "$HOME/invidious"
    fi
    
    if [ ! -d "$HOME/homeasset" ]; then
        echo -e "${BOLD_CYAN}🔄 HomeAsset missing. Cloning repository...${RESET}"
        git clone https://github.com/pmitchell-dev/HomeAsset.git "$HOME/homeasset"
        if [ -f "$SCRIPT_DIR/homeasset-compose.yml" ]; then
            cp "$SCRIPT_DIR/homeasset-compose.yml" "$HOME/homeasset/docker-compose.yml"
        fi
    fi

    if [ -d "$HOME/homeasset" ]; then
        echo -e "${BOLD_CYAN}🔄 Checking & pulling latest HomeAsset code from GitHub...${RESET}"
        cd "$HOME/homeasset"
        # Auto-heal remote URL to point to pmitchell-dev/HomeAsset.git
        git remote set-url origin https://github.com/pmitchell-dev/HomeAsset.git 2>/dev/null || true
        # Discard local changes to tracked files (like docker-compose.yml) to ensure git pull succeeds
        git checkout -- .
        
        BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || git pull
        AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

        if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${BOLD_YELLOW}🚀 NEW UPDATES DETECTED & PULLED [HomeAsset]${RESET}"
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${CYAN} Repository:${RESET}   https://github.com/pmitchell-dev/HomeAsset"
            echo -e "${CYAN} Commit Range:${RESET} ${BEFORE_PULL:~0:7}..${AFTER_PULL:~0:7}"
            echo -e "${CYAN} New Commits:${RESET}"
            git log --oneline -n 5 "$BEFORE_PULL..$AFTER_PULL" | sed 's/^/   • /'
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
        else
            echo -e "  ${CYAN}[HomeAsset]${RESET} Already up to date (no new changes found)."
        fi

        echo -e "${BOLD_CYAN}🔨 Rebuilding local HomeAsset image...${RESET}"
        # Rebuilds from your modified source code using the compose file
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo -e "  ⚠ Warning: No docker-compose.yml found in $HOME/homeasset"
        fi
        echo -e "  ✅ HomeAsset Deployment Check Complete."
    fi

    # RustDesk Stack Synchronization
    if [ ! -d "$HOME/rustdesk" ]; then
        echo "?? RustDesk missing. Provisioning stack..."
        mkdir -p "$HOME/rustdesk/data"
        if [ -f "$SCRIPT_DIR/rustdesk-compose.yml" ]; then
            cp "$SCRIPT_DIR/rustdesk-compose.yml" "$HOME/rustdesk/docker-compose.yml"
        fi
    fi

    if [ -d "$HOME/rustdesk" ]; then
        echo "?? Synchronizing RustDesk Stack..."
        cd "$HOME/rustdesk"
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "? RustDesk Stack Deployment Check Complete."
        else
            echo "? Warning: No docker-compose.yml found in $HOME/rustdesk"
        fi
    fi

    # JobBoard Stack Synchronization
    if [ ! -d "$HOME/jobboard" ]; then
        echo "📋 JobBoard missing. Cloning repository..."
        git clone https://github.com/pmitchell-dev/JobBoard.git "$HOME/jobboard"
        mkdir -p "$HOME/jobboard/data/backups"
        mkdir -p "$HOME/jobboard/cache"
        # Ensure user 1000:1000 owns these dirs so the container can write to them
        sudo chown -R 1000:1000 "$HOME/jobboard/data" "$HOME/jobboard/cache"
    fi

    if [ -d "$HOME/jobboard" ]; then
        echo -e "${BOLD_CYAN}📋 Checking & pulling latest JobBoard code from GitHub...${RESET}"
        cd "$HOME/jobboard"
        git remote set-url origin https://github.com/pmitchell-dev/JobBoard.git 2>/dev/null || true

        # Safe pull: preserve live jobs data across git operations.
        if [ -f "data/jobs.json" ]; then
            cp data/jobs.json /tmp/jobs.json.bak
            echo "📋 Stashed jobs.json to /tmp/jobs.json.bak"
        fi
        git checkout -- .

        # Also untrack from local index if git still has it
        git ls-files --error-unmatch data/jobs.json &>/dev/null 2>&1 && git rm --cached data/jobs.json
        rm -f data/jobs.json

        BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
        git pull origin master 2>/dev/null || git pull origin main 2>/dev/null || git pull
        AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

        if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${BOLD_YELLOW}🚀 NEW UPDATES DETECTED & PULLED [JobBoard]${RESET}"
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${CYAN} Repository:${RESET}   https://github.com/pmitchell-dev/JobBoard"
            echo -e "${CYAN} Commit Range:${RESET} ${BEFORE_PULL:~0:7}..${AFTER_PULL:~0:7}"
            echo -e "${CYAN} New Commits:${RESET}"
            git log --oneline -n 5 "$BEFORE_PULL..$AFTER_PULL" | sed 's/^/   • /'
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
        else
            echo -e "  ${CYAN}[JobBoard]${RESET} Already up to date (no new changes found)."
        fi

        # Restore live data
        if [ -f "/tmp/jobs.json.bak" ]; then
            cp /tmp/jobs.json.bak data/jobs.json
            echo "📋 Restored jobs.json from stash"
        fi
        sudo chown -R 1000:1000 "$HOME/jobboard/data" "$HOME/jobboard/cache"

        # Always restore our port-remapped compose
        if [ -f "$SCRIPT_DIR/jobboard-compose.yml" ]; then
            cp "$SCRIPT_DIR/jobboard-compose.yml" "$HOME/jobboard/docker-compose.yml"
        fi

        # Clear and refresh the JobBoard cache
        echo "🧹 Clearing JobBoard cache..."
        sudo rm -rf "$HOME/jobboard/cache/*"

        echo -e "${BOLD_CYAN}🔨 Rebuilding local JobBoard image...${RESET}"
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build --force-recreate
        else
            echo -e "  ⚠ Warning: No docker-compose.yml found in $HOME/jobboard"
        fi
        echo "✅ JobBoard Deployment Complete. (http://$HOST_IP:3001)"
    fi



    # Gemini API Stack Synchronization
    if [ ! -d "$HOME/gemini-api" ]; then
        echo "🤖 Gemini API Stack missing. Provisioning stack..."
        mkdir -p "$HOME/gemini-api"
    fi

    if [ -d "$HOME/gemini-api" ]; then
        echo "🤖 Synchronizing Gemini API Stack..."
        cd "$HOME/gemini-api"
        if [ -f "$SCRIPT_DIR/gemini-compose.yml" ]; then
            cp "$SCRIPT_DIR/gemini-compose.yml" "$HOME/gemini-api/docker-compose.yml"
        fi
        if [ -f "$SCRIPT_DIR/gemini_api_server.py" ]; then
            cp "$SCRIPT_DIR/gemini_api_server.py" "$HOME/gemini-api/gemini_api_server.py"
        fi
        if [ -f "$SCRIPT_DIR/Dockerfile.gemini" ]; then
            cp "$SCRIPT_DIR/Dockerfile.gemini" "$HOME/gemini-api/Dockerfile.gemini"
        fi
        if [ ! -f ".env" ]; then
            echo "GEMINI_API_KEY=your_gemini_api_key_here" > .env
            echo "🔑 Created $HOME/gemini-api/.env (Add your real GEMINI_API_KEY)"
        fi
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
            echo "✅ Gemini API Deployment Complete. (http://$HOST_IP:5050/api/query)"
        else
            echo "⚠ Warning: No docker-compose.yml found in $HOME/gemini-api"
        fi
    fi

    # RelayIT Stack Synchronization
    if [ ! -d "$HOME/relayit" ]; then
        echo -e "${BOLD_CYAN}🎟️ RelayIT missing. Cloning repository...${RESET}"
        git clone https://github.com/pmitchell-dev/RelayIT.git "$HOME/relayit"
        if [ -f "$SCRIPT_DIR/relayit-compose.yml" ]; then
            cp "$SCRIPT_DIR/relayit-compose.yml" "$HOME/relayit/docker-compose.yml"
        fi
    fi

    if [ -d "$HOME/relayit" ]; then
        echo -e "${BOLD_CYAN}🎟️ Checking & pulling latest RelayIT code from GitHub...${RESET}"
        cd "$HOME/relayit"
        git remote set-url origin https://github.com/pmitchell-dev/RelayIT.git 2>/dev/null || true

        BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
        git fetch origin 2>/dev/null
        git reset --hard origin/main 2>/dev/null || git reset --hard origin/master 2>/dev/null || git pull origin main 2>/dev/null || git pull
        AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)

        if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${BOLD_YELLOW}🚀 NEW UPDATES DETECTED & PULLED [RelayIT]${RESET}"
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
            echo -e "${CYAN} Repository:${RESET}   https://github.com/pmitchell-dev/RelayIT"
            echo -e "${CYAN} Commit Range:${RESET} ${BEFORE_PULL:~0:7}..${AFTER_PULL:~0:7}"
            echo -e "${CYAN} New Commits:${RESET}"
            git log --oneline -n 5 "$BEFORE_PULL..$AFTER_PULL" | sed 's/^/   • /'
            echo -e "${BOLD_GREEN}========================================================================${RESET}"
        else
            echo -e "  ${CYAN}[RelayIT]${RESET} Already up to date (no new changes found)."
        fi

        if [ -f "$SCRIPT_DIR/relayit-compose.yml" ]; then
            cp "$SCRIPT_DIR/relayit-compose.yml" "$HOME/relayit/docker-compose.yml"
        fi

        echo -e "${BOLD_CYAN}🧹 Wiping Python bytecode caches (__pycache__)...${RESET}"
        find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

        echo -e "${BOLD_CYAN}🔨 Rebuilding local RelayIT image (no cache)...${RESET}"
        if [ -f "docker-compose.yml" ]; then
            docker compose down --remove-orphans 2>/dev/null || true
            docker compose build --no-cache
            docker compose up -d --force-recreate
        else
            echo -e "  ⚠ Warning: No docker-compose.yml found in $HOME/relayit"
        fi
        echo "✅ RelayIT Deployment Complete. (http://$HOST_IP)"
    fi

    # Webhost Maintenance Crontab
    WEB_CRON="0 0 * * * $SCRIPT_DIR/pi_backup.sh --mode webhost
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -

    # Dozzle Log Viewer Stack Sync
    if [ -d "$HOME/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Log Viewer..."
        if [ -f "$SCRIPT_DIR/dozzle-compose.yml" ]; then
            cp "$SCRIPT_DIR/dozzle-compose.yml" "$HOME/dozzle/docker-compose.yml"
        fi
        cd "$HOME/dozzle" && sudo docker compose up -d --remove-orphans
        echo "✅ Dozzle Log Viewer synced. (http://$HOST_IP:8888)"
    fi
fi


# ──────────────────────────────────────────────
# TerminalBuddy Setup (embedded — no internet required)
# ──────────────────────────────────────────────
echo "→ Setting up TerminalBuddy..."

mkdir -p ~/.config/terminalbuddy

cat > ~/.config/terminalbuddy/terminalbuddy.sh << 'TERMINALBUDDY_EOF'
#!/usr/bin/env bash
# TerminalBuddy Shell Integration Script
[[ "$TERM" == "dumb" ]] && return

__tb_osc() {
    printf '\e]7701;%s\a' "$1"
}

__tb_strip_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*[mGKHF]//g; s/\x1b\][^\x07]*\x07//g; s/\x1b[()][ -~]//g'
}

__tb_preexec() {
    local full_cmd="$1"
    local cmd
    cmd=$(echo "$full_cmd" | awk '{print $1}' | xargs basename 2>/dev/null || echo "$full_cmd")
    __tb_osc "cmd=${cmd}"
}

__tb_precmd() {
    local cwd="$PWD"
    local dashboard_b64=""

    if [[ -f "${HOME}/dashboard/dashboard.txt" ]]; then
        local raw
        raw=$(cat "${HOME}/dashboard/dashboard.txt")
        local stripped
        stripped=$(__tb_strip_ansi "$raw")
        dashboard_b64=$(echo "$stripped" | base64 -w 0 2>/dev/null || echo "$stripped" | base64)
    fi

    __tb_osc "prompt;cwd=${cwd};dashboard=${dashboard_b64}"
}

if [[ -n "$BASH_VERSION" ]]; then
    __tb_prev_debug_trap=$(trap -p DEBUG | sed "s/trap -- '\(.*\)' DEBUG/\1/")
    if [[ -z "$__tb_prev_debug_trap" ]]; then
        trap '__tb_preexec "$BASH_COMMAND"' DEBUG
    else
        trap "${__tb_prev_debug_trap}; __tb_preexec \"\$BASH_COMMAND\"" DEBUG
    fi
    if [[ -z "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND='__tb_precmd'
    else
        PROMPT_COMMAND="${PROMPT_COMMAND}; __tb_precmd"
    fi
fi

if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec __tb_preexec
    add-zsh-hook precmd __tb_precmd
fi
TERMINALBUDDY_EOF

chmod +x ~/.config/terminalbuddy/terminalbuddy.sh

if ! grep -qF 'terminalbuddy.sh' ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# TerminalBuddy shell integration' >> ~/.bashrc
    echo '[ -f ~/.config/terminalbuddy/terminalbuddy.sh ] && source ~/.config/terminalbuddy/terminalbuddy.sh' >> ~/.bashrc
fi

if ! grep -qF 'aliases.sh' ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# Gladstone aliases integration' >> ~/.bashrc
    echo '[ -f "$HOME/scripts/aliases.sh" ] && source "$HOME/scripts/aliases.sh"' >> ~/.bashrc
fi

if [ "$MODE" == "--webhost" ] || [ "$MODE" == "webhost" ]; then
    if ! grep -qF 'gemini_clean' ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'BASHRC_WEBHOST_ENV_EOF'

# Terminal and Gemini CLI environment fixes
export TERM=xterm-256color
export COLORTERM=truecolor

gemini_clean() {
  command gemini "$@"
  # Redirect stdin so stty sane never hangs waiting for input
  stty sane < /dev/null 2>/dev/null || true
  # Force-kill any lingering node CLI process if it stalls
  pkill -9 -f "@google/gemini-cli" 2>/dev/null || true
}

alias gemini='GEMINI_CLI_NO_RELAUNCH=1 node /usr/lib/node_modules/@google/gemini-cli/bundle/gemini.js'
BASHRC_WEBHOST_ENV_EOF
    fi
fi

mkdir -p ~/dashboard

echo "✓ TerminalBuddy setup complete"
# ──────────────────────────────────────────────

echo "✅ [$HOSTNAME] Rebuild Complete."