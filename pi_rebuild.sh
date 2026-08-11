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

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

# Ensure the scripts themselves are up to date
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "?? Updating scripts from GitHub..."
    SCRIPT_PATH=$(realpath "$0")
    cd "$SCRIPT_DIR" || exit
    BEFORE_PULL=$(git rev-parse HEAD 2>/dev/null)
    git pull --rebase origin main
    AFTER_PULL=$(git rev-parse HEAD 2>/dev/null)
    if [ "$BEFORE_PULL" != "$AFTER_PULL" ]; then
        echo "🔄 Scripts updated. Re-executing rebuild script..."
        exec /bin/bash "$SCRIPT_PATH" "$@"
    fi
fi


# --- 1. HUB MODE (Raspberry Pi Only) ---
if [ "$MODE" == "--ntfy" ]; then
    echo "📝 Applying Hub Crontab..."
    MASTER_CRON="0 0,8,12,16,20 * * * $SCRIPT_DIR/get_printer_status.sh
1 0,8,12,16,20 * * * $SCRIPT_DIR/printer_alert.sh
0 */6 * * * $SCRIPT_DIR/net_speed.sh
0 0 * * * $SCRIPT_DIR/pi_backup.sh
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
@reboot /bin/bash $SCRIPT_DIR/ntfy_listener.sh > $SCRIPT_DIR/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -

    # Dozzle Agent Stack Sync
    if [ -d "$HOME/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Agent..."
        if [ -f "$SCRIPT_DIR/dozzle-agent-compose.yml" ]; then
            cp "$SCRIPT_DIR/dozzle-agent-compose.yml" "$HOME/dozzle/docker-compose.yml"
        fi
        mkdir -p "$SCRIPT_DIR/logs"
        cd "$HOME/dozzle" && sudo docker compose up -d
        echo "✅ Dozzle Agent synced on port 7007."
    fi

# --- 2. WEBHOST MODE (Laptop Only) ---
elif [ "$MODE" == "--webhost" ]; then
    echo "?? Synchronizing Webhost Services..."
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    if [ ! -d "$HOME/homeasset" ]; then
        echo "?? HomeAsset missing. Cloning repository..."
        git clone https://github.com/legendary034/HomeAsset.git "$HOME/homeasset"
        if [ -f "$SCRIPT_DIR/homeasset-compose.yml" ]; then
            cp "$SCRIPT_DIR/homeasset-compose.yml" "$HOME/homeasset/docker-compose.yml"
        fi
    fi

    if [ -d "$HOME/homeasset" ]; then
        echo "?? Pulling latest HomeAsset code from GitHub..."
        cd "$HOME/homeasset"
        # Discard local changes to tracked files (like docker-compose.yml) to ensure git pull succeeds
        git checkout -- .
        git pull
        
        echo "?? Rebuilding local HomeAsset image..."
        # Rebuilds from your modified source code using the compose file
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo "? Warning: No docker-compose.yml found in $HOME/homeasset"
        fi
        echo "? Deployment Successful."
    fi

    # Invidious Stack Synchronization
    if [ -d "$HOME/invidious" ]; then
        echo "?? Synchronizing Invidious Stack..."
        cd "$HOME/invidious"
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "? Invidious Stack Deployment Check Complete."
        else
            echo "? Warning: No docker-compose.yml found in $HOME/invidious"
        fi
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
        echo "📋 Pulling latest JobBoard code from GitHub..."
        cd "$HOME/jobboard"

        # Safe pull: preserve live jobs data across git operations.
        if [ -f "data/jobs.json" ]; then
            cp data/jobs.json /tmp/jobs.json.bak
            echo "📋 Stashed jobs.json to /tmp/jobs.json.bak"
        fi
        git checkout -- .

        # Also untrack from local index if git still has it
        git ls-files --error-unmatch data/jobs.json &>/dev/null 2>&1 && git rm --cached data/jobs.json
        rm -f data/jobs.json

        git pull origin master

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

        echo "🔨 Rebuilding local JobBoard image..."
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build --force-recreate
        else
            echo "⚠ Warning: No docker-compose.yml found in $HOME/jobboard"
        fi
        echo "✅ JobBoard Deployment Complete. (http://$HOST_IP:3001)"
    fi

    # Open WebUI Stack Synchronization
    if [ ! -d "$HOME/open-webui" ]; then
        echo "🐳 Open WebUI missing. Provisioning stack..."
        mkdir -p "$HOME/open-webui/data"
    fi

    if [ -d "$HOME/open-webui" ]; then
        echo "🐳 Synchronizing Open WebUI Stack..."
        cd "$HOME/open-webui"
        if [ -f "$SCRIPT_DIR/open-webui-compose.yml" ]; then
            cp "$SCRIPT_DIR/open-webui-compose.yml" "$HOME/open-webui/docker-compose.yml"
        fi
        sudo chown -R 1000:1000 "$HOME/open-webui/data"
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "✅ Open WebUI Deployment Complete. (http://$HOST_IP:3002)"
        else
            echo "⚠ Warning: No docker-compose.yml found in $HOME/open-webui"
        fi
    fi

    # LiteLLM Stack Synchronization
    if [ ! -d "$HOME/litellm" ]; then
        echo "🐳 LiteLLM missing. Provisioning stack..."
        mkdir -p "$HOME/litellm"
    fi

    if [ -d "$HOME/litellm" ]; then
        echo "🐳 Synchronizing LiteLLM Stack..."
        cd "$HOME/litellm"
        if [ -f "$SCRIPT_DIR/litellm-compose.yml" ]; then
            cp "$SCRIPT_DIR/litellm-compose.yml" "$HOME/litellm/docker-compose.yml"
        fi
        if [ -f "$SCRIPT_DIR/litellm-config.yaml" ]; then
            cp "$SCRIPT_DIR/litellm-config.yaml" "config.yaml"
        fi
        if [ ! -f ".env" ]; then
            touch ".env"
        fi
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            docker compose restart litellm
            echo "✅ LiteLLM Deployment Complete. (http://$HOST_IP:4000)"
        else
            echo "⚠ Warning: No docker-compose.yml found in $HOME/litellm"
        fi
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

    # Webhost Maintenance Crontab
    WEB_CRON="0 0 * * * $SCRIPT_DIR/pi_backup.sh
*/5 * * * * $SCRIPT_DIR/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -

    # Dozzle Log Viewer Stack Sync
    if [ -d "$HOME/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Log Viewer..."
        if [ -f "$SCRIPT_DIR/dozzle-compose.yml" ]; then
            cp "$SCRIPT_DIR/dozzle-compose.yml" "$HOME/dozzle/docker-compose.yml"
        fi
        cd "$HOME/dozzle" && sudo docker compose up -d
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