#!/bin/bash
# ==========================================================
# GLADSTONE SERVICE WATCHDOG (v1.9)
# ==========================================================
REGISTRY="$HOME/scripts/services.registry"
LOG_DIR="$HOME/scripts/logs"
mkdir -p "$LOG_DIR"
RETRY_FILE="/tmp/service_retries"
ID_FILE="$HOME/.gladstone_mode"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

RESTORE_LOCK="/tmp/gladstone_restore_in_progress"
if [ -f "$RESTORE_LOCK" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏸️ Gladstone service watchdog paused during system restoration."
    exit 0
fi

MODE=$(cat "$ID_FILE" 2>/dev/null || echo "ntfy")
touch "$RETRY_FILE"

SCRIPT_DIR="$HOME/scripts"

# DOCKER MONITOR (Webhost Only)
if [ "$MODE" == "webhost" ]; then
    # HomeAsset
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "homeasset" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^homeasset$"; then
            echo "?? Recovering HomeAsset container..."
            cd "$HOME/homeasset" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
            COUNT=$(grep "^homeasset:" "$RETRY_FILE" | cut -d: -f2 || echo 0)
            NEW_COUNT=$((COUNT + 1))
            sed -i "/^homeasset:/d" "$RETRY_FILE"; echo "homeasset:$NEW_COUNT" >> "$RETRY_FILE"
            
            if [ "$NEW_COUNT" -ge 5 ]; then
                NOW=$(date +%s)
                MUTE_UNTIL=$(cat /tmp/gladstone_ntfy_mute 2>/dev/null || echo 0)
                if [[ "$MUTE_UNTIL" =~ ^[0-9]+$ ]] && [ "$NOW" -ge "$MUTE_UNTIL" ]; then
                    curl -H "Priority: 5" \
                         -H "Actions: http, Mute rest of the day, https://ntfy.sh/patrick_mitch_pi5_x9k2v_actions, method=POST, body=mute_watchdog" \
                         -d "[$HOSTNAME] ?? FATAL: HomeAsset Container Failed." ntfy.sh/$TOPIC
                fi
            fi
        else
            sed -i "/^homeasset:/d" "$RETRY_FILE"; echo "homeasset:0" >> "$RETRY_FILE"
        fi
    fi

    # RustDesk
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "rustdesk" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^hbbs$"; then
            echo "?? Recovering RustDesk ID server (hbbs)..."
            cd "$HOME/rustdesk" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
        if ! docker ps --format '{{.Names}}' | grep -q "^hbbr$"; then
            echo "?? Recovering RustDesk Relay server (hbbr)..."
            cd "$HOME/rustdesk" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
    fi

    # Gemini API
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "gemini-api" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^gemini-api$"; then
            echo "🤖 Recovering Gemini API container..."
            cd "$HOME/gemini-api" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
    fi

    # JobBoard
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "jobboard" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^jobboard$"; then
            echo "📋 Recovering JobBoard container..."
            cd "$HOME/jobboard" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
    fi

    # RelayIT
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "relayit" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^relayit"; then
            echo "🎟️ Recovering RelayIT container..."
            cd "$HOME/relayit" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
    fi
fi

# DOCKER MONITOR (Pi5 Hub Mode)
if [ "$MODE" == "ntfy" ]; then
    # Simple Login
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "simplelogin" 2>/dev/null; then
        if ! docker ps --format '{{.Names}}' | grep -q "^simplelogin-app$"; then
            echo "📧 Recovering Simple Login container..."
            cd "$HOME/simplelogin" 2>/dev/null && docker compose --progress=plain up -d >> "$LOG_DIR/services_manager.log" 2>&1
        fi
    fi
fi

# REGISTRY MONITOR (Shared)
grep '|' "$REGISTRY" 2>/dev/null | grep -v '^[[:space:]]*#' | while IFS='|' read -r service port desc; do
    s_key="${service%.sh}"
    if bash "$SCRIPT_DIR/pi_features.sh" --is-enabled "$s_key" 2>/dev/null; then
        if ! pgrep -fo "$service" > /dev/null; then
            nohup /bin/bash "$SCRIPT_DIR/$service" > "$LOG_DIR/${s_key}.log" 2>&1 &
        fi
    fi
done