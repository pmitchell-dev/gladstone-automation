#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (v1.7)
# ==========================================================
# Supports: RPi5 (Hub) & Ubuntu Laptop (Webhost)
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
ID_FILE="$HOME/.gladstone_mode"

# 1. Capture Flag from Command Line
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

# 2. Smart Fallback: Check existing ID if no flag provided
if [ -z "$MODE" ] && [ -f "$ID_FILE" ]; then
    MODE=$(cat "$ID_FILE" | xargs)
    echo "?? No flag detected. Using existing identity: $MODE"
elif [ -z "$MODE" ]; then
    echo "? ERROR: No mode specified! Usage: ./install.sh --ntfy | --webhost"
    exit 1
fi

# 3. Save Identity & Prep Directories
echo "$MODE" > "$ID_FILE"
mkdir -p "$SCRIPT_DIR/logs" "$SCRIPT_DIR/backup" "/home/pi/printer_data"

# 4. Mode-Specific Installation Logic
sudo apt update
if [ "$MODE" == "ntfy" ]; then
    echo "???  Installing Hub Tools (Speedtest, ntfy)..."
    sudo apt install -y jq curl git bc zip ntfy speedtest-cli

elif [ "$MODE" == "webhost" ]; then
    echo "?? Installing Webhost Stack (Docker + Compose)..."
    sudo apt install -y jq curl git bc zip
    
    # INSTALL DOCKER ENGINE (Official Script)
    if ! command -v docker &> /dev/null; then
        echo "?? Pulling Docker convenience script..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
    
    # INSTALL COMPOSE PLUGIN
    sudo apt install -y docker-compose-plugin

    # FORCE SERVICE START & PERMISSIONS
    echo "??  Waking up Docker services..."
    sudo systemctl enable --now docker
    
    # FORCE PATH REFRESH for this session
    export PATH="$PATH:/usr/bin:/usr/local/bin"
fi

# 5. Ownership & Global Permissions
echo "?? Enforcing Gladstone Permissions..."
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh

# 6. Alias Injection
if ! grep -q "aliases.sh" ~/.bashrc; then
    echo "source $SCRIPT_DIR/aliases.sh" >> ~/.bashrc
fi

# 7. Hand-off to Rebuild
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"
else
    echo "? Error: pi_rebuild.sh not found."
    exit 1
fi

echo "-------------------------------------------------------"
echo "? [$HOSTNAME] Gladstone v1.7 Installation Complete ($MODE)"
echo "?? Run 'source ~/.bashrc' or 'refresh' to start."
echo "-------------------------------------------------------"