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
        echo "?? Existing Invidious config updated (Captcha disabled)."
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