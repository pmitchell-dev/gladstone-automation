#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (v2.1)
# ==========================================================
SCRIPT_DIR="$HOME/scripts"
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
if [ -f "$ID_FILE" ]; then
    EXISTING_MODE=$(cat "$ID_FILE" | xargs)
    # Guard Rail 1: Prevent changing an established server's role
    if [ -n "$MODE" ] && [ "$MODE" != "$EXISTING_MODE" ]; then
        echo "❌ ERROR: This server is already designated as a '$EXISTING_MODE' server!"
        echo "You cannot run the install script with --$MODE here."
        exit 1
    fi
    if [ -z "$MODE" ]; then
        MODE=$EXISTING_MODE
    fi
elif [ -z "$MODE" ]; then
    echo "❓ ERROR: No mode specified! Usage: ./install.sh --ntfy | --webhost"
    exit 1
fi

# Guard Rail 2: Prevent fresh Pi installs from becoming a webhost
HOSTNAME=$(hostname)
if [ "$MODE" == "webhost" ] && [[ "$HOSTNAME" == *"raspberrypi"* || "$HOSTNAME" == *"pi"* ]]; then
    echo "❌ ERROR: Hostname suggests this is a Raspberry Pi!"
    echo "Please use './install.sh --ntfy' for the Hub."
    exit 1
fi

echo "$MODE" > "$ID_FILE"

# 3. Base System Update
echo "📦 Checking and installing system dependencies (jq, curl, git, bc, zip, cifs-utils, python3, smbclient)..."
sudo apt update && sudo apt install -y jq curl git bc zip cifs-utils python3 smbclient

# 3b. Docker Engine (required by both ntfy agent and webhost)
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# Install Compose plugin and enable Docker daemon
sudo apt install -y docker-compose-plugin
sudo systemctl enable --now docker
export PATH="$PATH:/usr/bin:/usr/local/bin"

# 4. Webhost Specific Logic (Code Cloning)
if [ "$MODE" == "webhost" ]; then
    echo "🖥️  Configuring Webhost Stack..."
    if [ ! -d "$HOME/homeasset" ]; then
        echo "🔄 Initial Clone of HomeAsset Repository..."
        git clone https://github.com/pmitchell-dev/HomeAsset.git "$HOME/homeasset"
        # Copy the provided docker-compose file for homeasset
        if [ -f "$SCRIPT_DIR/homeasset-compose.yml" ]; then
            cp "$SCRIPT_DIR/homeasset-compose.yml" "$HOME/homeasset/docker-compose.yml"
        fi
    fi


    # RustDesk Server Stack Setup
    RUSTDESK_DIR="$HOME/rustdesk"
    mkdir -p "$RUSTDESK_DIR/data"
    
    if [ -f "$SCRIPT_DIR/rustdesk-compose.yml" ]; then
        cp "$SCRIPT_DIR/rustdesk-compose.yml" "$RUSTDESK_DIR/docker-compose.yml"
        echo "?? RustDesk Stack provisioned."
    fi

    # JobBoard Stack Setup
    if [ ! -d "$HOME/jobboard" ]; then
        echo "📋 Initial Clone of JobBoard..."
        git clone https://github.com/pmitchell-dev/JobBoard.git "$HOME/jobboard"
        # Override upstream compose with our port-remapped version
        if [ -f "$SCRIPT_DIR/jobboard-compose.yml" ]; then
            cp "$SCRIPT_DIR/jobboard-compose.yml" "$HOME/jobboard/docker-compose.yml"
        fi
    fi
    # Ensure persistent host directories exist (survives container rebuilds)
    mkdir -p "$HOME/jobboard/data/backups"
    mkdir -p "$HOME/jobboard/cache"
    # Fix ownership so container user (1000:1000) can write to mounted volumes
    sudo chown -R 1000:1000 "$HOME/jobboard/data" "$HOME/jobboard/cache"



    # Gemini API Backend Stack Setup
    GEMINI_DIR="$HOME/gemini-api"
    mkdir -p "$GEMINI_DIR"
    if [ -f "$SCRIPT_DIR/gemini-compose.yml" ]; then
        cp "$SCRIPT_DIR/gemini-compose.yml" "$GEMINI_DIR/docker-compose.yml"
    fi
    if [ -f "$SCRIPT_DIR/gemini_api_server.py" ]; then
        cp "$SCRIPT_DIR/gemini_api_server.py" "$GEMINI_DIR/gemini_api_server.py"
    fi
    if [ -f "$SCRIPT_DIR/Dockerfile.gemini" ]; then
        cp "$SCRIPT_DIR/Dockerfile.gemini" "$GEMINI_DIR/Dockerfile.gemini"
    fi
    if [ ! -f "$GEMINI_DIR/.env" ]; then
        echo "GEMINI_API_KEY=your_gemini_api_key_here" > "$GEMINI_DIR/.env"
        echo "🔑 Created $GEMINI_DIR/.env file (Add your GEMINI_API_KEY here)."
    fi
    echo "🤖 Gemini API Stack provisioned."

    # RelayIT Stack Setup
    if [ ! -d "$HOME/relayit" ]; then
        echo "🎟️ Initial Clone of RelayIT..."
        git clone https://github.com/pmitchell-dev/RelayIT.git "$HOME/relayit"
        if [ -f "$SCRIPT_DIR/relayit-compose.yml" ]; then
            cp "$SCRIPT_DIR/relayit-compose.yml" "$HOME/relayit/docker-compose.yml"
        fi
    fi
    mkdir -p "$HOME/relayit/data/pgdata"
    mkdir -p "$HOME/relayit/data/caddy_data"
    mkdir -p "$HOME/relayit/data/caddy_config"
    echo "🎟️ RelayIT Stack provisioned."
fi

# 4b. Webhost — Dozzle Log Viewer Stack
if [ "$MODE" == "webhost" ]; then
    echo "📊 Deploying Dozzle Log Viewer (Webhost main instance)..."
    DOZZLE_DIR="$HOME/dozzle"
    mkdir -p "$DOZZLE_DIR"

    if [ -f "$SCRIPT_DIR/dozzle-compose.yml" ]; then
        cp "$SCRIPT_DIR/dozzle-compose.yml" "$DOZZLE_DIR/docker-compose.yml"
    fi

    cd "$DOZZLE_DIR"
    sudo docker compose up -d --remove-orphans
    echo "✅ Dozzle Log Viewer running at http://192.168.50.217:8888"
fi

# 4c. Pi5 Hub — Dozzle Agent Stack
if [ "$MODE" == "ntfy" ]; then
    echo "📊 Deploying Dozzle Agent (Pi5 hub)..."
    DOZZLE_DIR="$HOME/dozzle"
    mkdir -p "$DOZZLE_DIR"

    # Ensure the shared log directory exists (scripts write here)
    mkdir -p "$SCRIPT_DIR/logs"

    if [ -f "$SCRIPT_DIR/dozzle-agent-compose.yml" ]; then
        cp "$SCRIPT_DIR/dozzle-agent-compose.yml" "$DOZZLE_DIR/docker-compose.yml"
    fi

    cd "$DOZZLE_DIR"
    sudo docker compose up -d --remove-orphans
    echo "✅ Dozzle Agent running on port 7007 (connected to Webhost)"
fi

# 4d. Pi5 Hub — Simple Login Stack
if [ "$MODE" == "ntfy" ]; then
    echo "📧 Deploying Simple Login Stack (Pi5 hub)..."
    SIMPLELOGIN_DIR="$HOME/simplelogin"
    mkdir -p "$SIMPLELOGIN_DIR/data/pgdata"

    if [ -f "$SCRIPT_DIR/simplelogin-compose.yml" ]; then
        cp "$SCRIPT_DIR/simplelogin-compose.yml" "$SIMPLELOGIN_DIR/docker-compose.yml"
    fi

    cd "$SIMPLELOGIN_DIR"
    sudo docker compose down --remove-orphans 2>/dev/null || true
    sudo docker compose up -d --remove-orphans
    echo "✅ Simple Login running at http://simplelogin.localrepo.net:7777 (localrepo.net)"
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
if ! grep -qF 'terminalbuddy.sh' ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# TerminalBuddy shell integration' >> ~/.bashrc
    echo '[ -f ~/.config/terminalbuddy/terminalbuddy.sh ] && source ~/.config/terminalbuddy/terminalbuddy.sh' >> ~/.bashrc
fi

# Ensure aliases.sh is sourced in .bashrc
if ! grep -qF 'aliases.sh' ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# Gladstone aliases integration' >> ~/.bashrc
    echo '[ -f "$HOME/scripts/aliases.sh" ] && source "$HOME/scripts/aliases.sh"' >> ~/.bashrc
fi

# 5b. Webhost Bashrc Environment Fixes
if [ "$MODE" == "webhost" ]; then
    echo "⚙️  Ensuring Webhost .bashrc environment fixes..."
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
        echo "✅ Webhost Gemini CLI & terminal environment fixes appended to ~/.bashrc"
    fi
fi

# Ensure dashboard directory exists
mkdir -p ~/dashboard

echo "✓ TerminalBuddy setup complete"
# ──────────────────────────────────────────────

# 6. Permissions & Hand-off to Rebuild
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh
bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"