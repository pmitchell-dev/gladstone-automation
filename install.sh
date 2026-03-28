#!/bin/bash
# ==========================================================
# GLADSTONE SMART BOOTSTRAP (install.sh)
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
ID_FILE="$HOME/.gladstone_mode"

# 1. Try to get Mode from Command Line Flag
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

# 2. FALLBACK: If no flag, check for existing ID Card
if [ -z "$MODE" ] && [ -f "$ID_FILE" ]; then
    MODE=$(cat "$ID_FILE" | xargs)
    echo "?? No flag detected. Using existing identity: $MODE"
fi

# 3. FINAL SAFETY: If still no mode, THEN error out.
if [ -z "$MODE" ]; then
    echo "? ERROR: No mode specified and no existing identity found!"
    echo "Usage: ./install.sh --ntfy  OR  ./install.sh --webhost"
    exit 1
fi

# 4. Persistence (Ensures the file stays up to date)
echo "$MODE" > "$ID_FILE"

# ... [The rest of your standard install.sh logic] ...

# 5. Hand-off to Rebuild (Passes the identified mode)
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"
else
    echo "? Error: pi_rebuild.sh not found."
    exit 1
fi