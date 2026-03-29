#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (v1.9)
# ==========================================================
SCRIPT_DIR="/home/pi/scripts"
ID_FILE="$HOME/.gladstone_mode"

# 1. Capture Flag
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

# 2. Identity Check
if [ -z "$MODE" ] && [ -f "$ID_FILE" ]; then
    MODE=$(cat "$ID_FILE" | xargs)
elif [ -z "$MODE" ]; then
    echo "? ERROR: No mode specified!"
    exit 1
fi
echo "$MODE" > "$ID_FILE"

# 3. System Prep
sudo apt update && sudo apt install -y jq curl git bc zip

if [ "$MODE" == "webhost" ]; then
    echo "?? Configuring Webhost Stack..."
    # Install Docker if missing
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
    sudo apt install -y docker-compose-plugin
    sudo systemctl enable --now docker
    export PATH="$PATH:/usr/bin:/usr/local/bin"

    # CLONE HOMEBOX FORK
    if [ ! -d "/home/pi/homebox" ]; then
        echo "?? Cloning Custom Homebox Fork..."
        git clone https://github.com/legendary034/homebox.git /home/pi/homebox
    fi
fi

# 4. Finalize
sudo chown -R $USER:$USER "$SCRIPT_DIR"
chmod +x $SCRIPT_DIR/*.sh
bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"