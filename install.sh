#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (v2.0)
# ==========================================================
SCRIPT_DIR="/home/pi/scripts"
ID_FILE="$HOME/.gladstone_mode"

# 1. Capture Flag (ntfy for Hub, webhost for Laptop)
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

# 2. Identity Check & Persistence
if [ -z "$MODE" ] && [ -f "$ID_FILE" ]; then
    MODE=$(cat "$ID_FILE" | xargs)
elif [ -z "$MODE" ]; then
    echo "? ERROR: No mode specified! Usage: ./install.sh --ntfy | --webhost"
    exit 1
fi
echo "$MODE" > "$ID_FILE"

# 3. Base System Update
sudo apt update && sudo apt install -y jq curl git bc zip

# 4. Webhost Specific Logic (Docker + Code Cloning)
if [ "$MODE" == "webhost" ]; then
    echo "?? Configuring Webhost Stack..."
    
    # Install Docker Engine if missing
    if ! command -v docker &> /dev/null; then
        echo "?? Installing Docker Engine..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
    
    # Install Compose and wake up services
    sudo apt install -y docker-compose-plugin
    sudo systemctl enable --now docker
    export PATH="$PATH:/usr/bin:/usr/local/bin"

    # Clone your custom HomeAsset Fork
    if [ ! -d "/home/pi/homeasset" ]; then
        echo "?? Initial Clone of HomeAsset Fork..."
        git clone https://github.com/legendary034/HomeAsset.git /home/pi/homeasset
        # Copy the provided docker-compose file for homeasset
        if [ -f "$SCRIPT_DIR/homeasset-compose.yml" ]; then
            cp "$SCRIPT_DIR/homeasset-compose.yml" "/home/pi/homeasset/docker-compose.yml"
        fi
    fi

    # 4a. Invidious Stack Setup (Standard/Optional Items)
    INVID_DIR="/home/pi/invidious"
    mkdir -p "$INVID_DIR/config"
    mkdir -p "$INVID_DIR/postgresdata"
    
    # Self-healing: Ensure config.yml is a file, NOT a directory (fix Docker accidental mounts)
    if [ -d "$INVID_DIR/config/config.yml" ]; then
        echo "?? Fixing accidental Docker directory mount for config.yml..."
        sudo rm -rf "$INVID_DIR/config/config.yml"
    fi

    # Fix permissions for the config files (db data handled by docker)
    sudo chown -R $USER:$USER "$INVID_DIR/config"
    chmod -R 755 "$INVID_DIR"

    # Always ensure the latest stack definition is present
    if [ -f "$SCRIPT_DIR/invidious-compose.yml" ]; then
        cp "$SCRIPT_DIR/invidious-compose.yml" "$INVID_DIR/docker-compose.yml"
    fi

    if [ -f "$SCRIPT_DIR/init-db.sql" ]; then
        cp "$SCRIPT_DIR/init-db.sql" "$INVID_DIR/init-db.sql"
    fi

    if [ -f "$SCRIPT_DIR/pi_invidious_wipe.sh" ]; then
        cp "$SCRIPT_DIR/pi_invidious_wipe.sh" "$INVID_DIR/pi_invidious_wipe.sh"
    fi

    if [ -f "$SCRIPT_DIR/apply_schema_fix.sh" ]; then
        cp "$SCRIPT_DIR/apply_schema_fix.sh" "$INVID_DIR/apply_schema_fix.sh"
    fi

    # Retrieve or Generate Secrets
    HMAC_KEY=""
    COMPANION_KEY=""

    if [ -f "$INVID_DIR/config/config.yml" ]; then
        # Try to extract existing keys to maintain consistency
        HMAC_KEY=$(grep "hmac_key:" "$INVID_DIR/config/config.yml" | awk '{print $2}' | tr -d '"')
        COMPANION_KEY=$(grep "invidious_companion_key:" "$INVID_DIR/config/config.yml" | awk '{print $2}' | tr -d '"')
    fi

    if [ -z "$HMAC_KEY" ]; then
        HMAC_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    fi
    if [ -z "$COMPANION_KEY" ]; then
        COMPANION_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    fi

    # Always ensure the compose file environment is synchronized
    if [ -f "$INVID_DIR/docker-compose.yml" ]; then
        # Create/Update .env file in the deployment directory
        echo "COMPANION_KEY=$COMPANION_KEY" > "$INVID_DIR/.env"
        echo "?? Synchronized .env file for Docker Compose."
    fi

    # Provision/Update Configuration
    if [ ! -f "$INVID_DIR/config/config.yml" ]; then
        echo "?? Provisioning new Invidious configuration..."
        if [ -f "$SCRIPT_DIR/invidious-config.yml.template" ]; then
            sed -e "s/\${HMAC_KEY}/$HMAC_KEY/g" \
                -e "s/\${COMPANION_KEY}/$COMPANION_KEY/g" \
                "$SCRIPT_DIR/invidious-config.yml.template" > "$INVID_DIR/config/config.yml"
            
            echo "?? Invidious config created in $INVID_DIR/config/config.yml"
        fi
    else
        # Force disable captcha in existing config if it was already provisioned
        if grep -q "captcha_enabled:" "$INVID_DIR/config/config.yml"; then
            sed -i "s/captcha_enabled: .*/captcha_enabled: false/" "$INVID_DIR/config/config.yml"
        else
            echo "captcha_enabled: false" >> "$INVID_DIR/config/config.yml"
        fi
        
        # Force empty domain for IP access
        if grep -q "^domain:" "$INVID_DIR/config/config.yml"; then
            sed -i "s/^domain:.*/domain: \"\"/" "$INVID_DIR/config/config.yml"
        else
            echo "domain: \"\"" >> "$INVID_DIR/config/config.yml"
        fi
        echo "?? Existing Invidious config updated (Captcha disabled & Domain cleared)."
    fi

    # RustDesk Server Stack Setup
    RUSTDESK_DIR="/home/pi/rustdesk"
    mkdir -p "$RUSTDESK_DIR/data"
    
    if [ -f "$SCRIPT_DIR/rustdesk-compose.yml" ]; then
        cp "$SCRIPT_DIR/rustdesk-compose.yml" "$RUSTDESK_DIR/docker-compose.yml"
        echo "?? RustDesk Stack provisioned."
    fi

    # JobBoard Stack Setup
    if [ ! -d "/home/pi/jobboard" ]; then
        echo "📋 Initial Clone of JobBoard..."
        git clone https://github.com/pmitchell-dev/JobBoard.git /home/pi/jobboard
    fi
    # Ensure persistent host directories exist (survives container rebuilds)
    mkdir -p /home/pi/jobboard/data/backups
    mkdir -p /home/pi/jobboard/cache

    # Clone your custom HiveMind Fork (Temporarily Disabled)
    #if [ ! -d "/home/pi/hivemind" ]; then
    #    echo "?? Initial Clone of HiveMind Fork..."
    #    git clone https://github.com/legendary034/HiveMind.git /home/pi/hivemind
    #    # Copy the provided docker-compose file
    #    if [ -f "$SCRIPT_DIR/hivemind-compose.yml" ]; then
    #        cp "$SCRIPT_DIR/hivemind-compose.yml" "/home/pi/hivemind/docker-compose.yml"
    #    fi
    #fi
fi

# 5. TerminalBuddy Setup (embedded — no internet required)
# ──────────────────────────────────────────────
echo "→ Setting up TerminalBuddy..."

# Create the config directory
mkdir -p ~/.config/terminalbuddy

# Write the shell integration script directly (no download needed)
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

# Add to .bashrc (idempotent — won't duplicate on rebuild)
if ! grep -qF 'terminalbuddy.sh' ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# TerminalBuddy shell integration' >> ~/.bashrc
    echo '[ -f ~/.config/terminalbuddy/terminalbuddy.sh ] && source ~/.config/terminalbuddy/terminalbuddy.sh' >> ~/.bashrc
fi

# Ensure dashboard directory exists
mkdir -p ~/dashboard

echo "✓ TerminalBuddy setup complete"
# ──────────────────────────────────────────────

# 6. Permissions & Hand-off to Rebuild
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh
bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"