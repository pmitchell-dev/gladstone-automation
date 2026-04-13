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

# 5. Permissions & Hand-off to Rebuild
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh
bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"