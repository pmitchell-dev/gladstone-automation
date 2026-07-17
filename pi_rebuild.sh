#!/bin/bash
# ==========================================================
# GLADSTONE MULTI-MODE REBUILD (v2.0 - Auto-Sync)
# ==========================================================
MODE=$1 
if [ -z "$MODE" ] && [ -f "$HOME/.gladstone_mode" ]; then
    MODE="--$(cat $HOME/.gladstone_mode | xargs)"
fi
exec > >(tee -a /home/pi/scripts/logs/rebuild.log) 2>&1

echo "???  [$HOSTNAME] Rebuilding in $MODE mode..."

# Ensure the scripts themselves are up to date
if [ -d "/home/pi/scripts/.git" ]; then
    echo "?? Updating scripts from GitHub..."
    cd /home/pi/scripts && git pull --rebase origin main
fi


# --- 1. HUB MODE (Raspberry Pi Only) ---
if [ "$MODE" == "--ntfy" ]; then
    echo "📝 Applying Hub Crontab..."
    MASTER_CRON="0 0,8,12,16,20 * * * /home/pi/scripts/get_printer_status.sh
1 0,8,12,16,20 * * * /home/pi/scripts/printer_alert.sh
0 */6 * * * /home/pi/scripts/net_speed.sh
0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
@reboot /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/scripts/logs/ntfy.log 2>&1 &"
    echo "$MASTER_CRON" | crontab -

    # Dozzle Agent Stack Sync
    if [ -d "/home/pi/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Agent..."
        if [ -f "/home/pi/scripts/dozzle-agent-compose.yml" ]; then
            cp "/home/pi/scripts/dozzle-agent-compose.yml" "/home/pi/dozzle/docker-compose.yml"
        fi
        mkdir -p /home/pi/scripts/logs
        cd /home/pi/dozzle && sudo docker compose up -d
        echo "✅ Dozzle Agent synced on port 7007."
    fi

# --- 2. WEBHOST MODE (Laptop Only) ---
elif [ "$MODE" == "--webhost" ]; then
    echo "?? Synchronizing Webhost Services..."
    
    if [ ! -d "/home/pi/homeasset" ]; then
        echo "?? HomeAsset missing. Cloning repository..."
        git clone https://github.com/legendary034/HomeAsset.git /home/pi/homeasset
        if [ -f "/home/pi/scripts/homeasset-compose.yml" ]; then
            cp "/home/pi/scripts/homeasset-compose.yml" "/home/pi/homeasset/docker-compose.yml"
        fi
    fi

    if [ -d "/home/pi/homeasset" ]; then
        echo "?? Pulling latest HomeAsset code from GitHub..."
        cd /home/pi/homeasset
        git pull
        
        echo "?? Rebuilding local HomeAsset image..."
        # Rebuilds from your modified source code using the compose file
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo "? Warning: No docker-compose.yml found in /home/pi/homeasset"
        fi
        echo "? Deployment Successful."
    fi

    # Invidious Stack Synchronization
    if [ -d "/home/pi/invidious" ]; then
        echo "?? Synchronizing Invidious Stack..."
        cd /home/pi/invidious
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "? Invidious Stack Deployment Check Complete."
        else
            echo "? Warning: No docker-compose.yml found in /home/pi/invidious"
        fi
    fi

    # RustDesk Stack Synchronization
    if [ ! -d "/home/pi/rustdesk" ]; then
        echo "?? RustDesk missing. Provisioning stack..."
        mkdir -p "/home/pi/rustdesk/data"
        if [ -f "/home/pi/scripts/rustdesk-compose.yml" ]; then
            cp "/home/pi/scripts/rustdesk-compose.yml" "/home/pi/rustdesk/docker-compose.yml"
        fi
    fi

    if [ -d "/home/pi/rustdesk" ]; then
        echo "?? Synchronizing RustDesk Stack..."
        cd /home/pi/rustdesk
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "? RustDesk Stack Deployment Check Complete."
        else
            echo "? Warning: No docker-compose.yml found in /home/pi/rustdesk"
        fi
    fi

    # JobBoard Stack Synchronization
    if [ ! -d "/home/pi/jobboard" ]; then
        echo "📋 JobBoard missing. Cloning repository..."
        git clone https://github.com/pmitchell-dev/JobBoard.git /home/pi/jobboard
        mkdir -p /home/pi/jobboard/data/backups
        mkdir -p /home/pi/jobboard/cache
        # Ensure pi user owns these dirs so the container (user: 1000:1000) can write to them
        chown -R 1000:1000 /home/pi/jobboard/data /home/pi/jobboard/cache
    fi

    if [ -d "/home/pi/jobboard" ]; then
        echo "📋 Pulling latest JobBoard code from GitHub..."
        cd /home/pi/jobboard

        # Safe pull: preserve live jobs data across git operations.
        # data/jobs.json may still be tracked in the remote repo, so we
        # stash it, let git do the pull, then restore the real data.
        if [ -f "data/jobs.json" ]; then
            cp data/jobs.json /tmp/jobs.json.bak
            echo "📋 Stashed jobs.json to /tmp/jobs.json.bak"
        fi
        # Also untrack from local index if git still has it (older clone migration)
        git ls-files --error-unmatch data/jobs.json &>/dev/null 2>&1 && git rm --cached data/jobs.json
        rm -f data/jobs.json

        git pull

        # Restore live data — always prefer the real file over whatever git pulled
        if [ -f "/tmp/jobs.json.bak" ]; then
            cp /tmp/jobs.json.bak data/jobs.json
            echo "📋 Restored jobs.json from stash"
        fi
        # Re-assert ownership after cp/git ops (script may run as ntfy/cron user)
        sudo chown -R 1000:1000 /home/pi/jobboard/data /home/pi/jobboard/cache

        # Always restore our port-remapped compose (git pull may reset it)
        if [ -f "/home/pi/scripts/jobboard-compose.yml" ]; then
            cp "/home/pi/scripts/jobboard-compose.yml" "/home/pi/jobboard/docker-compose.yml"
        fi

        echo "🔨 Rebuilding local JobBoard image..."
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d --build
        else
            echo "⚠ Warning: No docker-compose.yml found in /home/pi/jobboard"
        fi
        echo "✅ JobBoard Deployment Complete. (http://localhost:3001)"
    fi

    # Open WebUI Stack Synchronization
    if [ ! -d "/home/pi/open-webui" ]; then
        echo "🐳 Open WebUI missing. Provisioning stack..."
        mkdir -p "/home/pi/open-webui/data"
    fi

    if [ -d "/home/pi/open-webui" ]; then
        echo "🐳 Synchronizing Open WebUI Stack..."
        cd /home/pi/open-webui
        if [ -f "/home/pi/scripts/open-webui-compose.yml" ]; then
            cp "/home/pi/scripts/open-webui-compose.yml" "/home/pi/open-webui/docker-compose.yml"
        fi
        sudo chown -R 1000:1000 /home/pi/open-webui/data
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "✅ Open WebUI Deployment Complete. (http://localhost:3002)"
        else
            echo "⚠ Warning: No docker-compose.yml found in /home/pi/open-webui"
        fi
    fi

    # LiteLLM Stack Synchronization
    if [ ! -d "/home/pi/litellm" ]; then
        echo "🐳 LiteLLM missing. Provisioning stack..."
        mkdir -p "/home/pi/litellm"
    fi

    if [ -d "/home/pi/litellm" ]; then
        echo "🐳 Synchronizing LiteLLM Stack..."
        cd /home/pi/litellm
        if [ -f "/home/pi/scripts/litellm-compose.yml" ]; then
            cp "/home/pi/scripts/litellm-compose.yml" "/home/pi/litellm/docker-compose.yml"
        fi
        if [ -f "/home/pi/scripts/litellm-config.yaml" ] && [ ! -f "config.yaml" ]; then
            cp "/home/pi/scripts/litellm-config.yaml" "config.yaml"
        fi
        if [ -f "docker-compose.yml" ]; then
            docker compose up -d
            echo "✅ LiteLLM Deployment Complete. (http://localhost:4000)"
        else
            echo "⚠ Warning: No docker-compose.yml found in /home/pi/litellm"
        fi
    fi

    # HiveMind Temporarily Disabled
    #if [ ! -d "/home/pi/hivemind" ]; then
    #    echo "?? HiveMind missing. Cloning repository..."
    #    git clone https://github.com/legendary034/HiveMind.git /home/pi/hivemind
    #    if [ -f "/home/pi/scripts/hivemind-compose.yml" ]; then
    #        cp "/home/pi/scripts/hivemind-compose.yml" "/home/pi/hivemind/docker-compose.yml"
    #    fi
    #fi
#
    #if [ -d "/home/pi/hivemind" ]; then
    #    echo "?? Pulling latest HiveMind code from GitHub..."
    #    cd /home/pi/hivemind
    #    git pull
    #    
    #    echo "?? Rebuilding local HiveMind image..."
    #    # If a docker-compose.yml is present, it will build and run it
    #    if [ -f "docker-compose.yml" ]; then
    #        docker compose up -d --build
    #    else
    #        echo "? Warning: No docker-compose.yml found in /home/pi/hivemind"
    #    fi
    #    echo "? HiveMind Deployment Check Complete."
    #fi

    # Webhost Maintenance Crontab
    WEB_CRON="0 0 * * * /home/pi/scripts/pi_backup.sh
*/5 * * * * /home/pi/scripts/pi_services_manager.sh
0 3 * * 0 docker system prune -af --volumes"
    echo "$WEB_CRON" | crontab -

    # Dozzle Log Viewer Stack Sync
    if [ -d "/home/pi/dozzle" ]; then
        echo "📊 Synchronizing Dozzle Log Viewer..."
        if [ -f "/home/pi/scripts/dozzle-compose.yml" ]; then
            cp "/home/pi/scripts/dozzle-compose.yml" "/home/pi/dozzle/docker-compose.yml"
        fi
        cd /home/pi/dozzle && sudo docker compose up -d
        echo "✅ Dozzle Log Viewer synced. (http://192.168.50.217:8888)"
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

if ! grep -qF 'terminalbuddy.sh' ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# TerminalBuddy shell integration' >> ~/.bashrc
    echo '[ -f ~/.config/terminalbuddy/terminalbuddy.sh ] && source ~/.config/terminalbuddy/terminalbuddy.sh' >> ~/.bashrc
fi

mkdir -p ~/dashboard

echo "✓ TerminalBuddy setup complete"
# ──────────────────────────────────────────────

echo "✅ [$HOSTNAME] Rebuild Complete."