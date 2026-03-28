#!/bin/bash
# ==========================================================
# GLADSTONE UNIVERSAL BOOTSTRAP (install.sh)
# ==========================================================
# USAGE: ./install.sh --ntfy  OR  ./install.sh --webhost
# ==========================================================

SCRIPT_DIR="/home/pi/scripts"
LOG_DIR="$SCRIPT_DIR/logs"
BACKUP_DIR="$SCRIPT_DIR/backup"

# 1. Capture and Validate Mode Flag
MODE=""
for arg in "$@"; do
    case $arg in
        --ntfy) MODE="ntfy" ;;
        --webhost) MODE="webhost" ;;
    esac
done

if [ -z "$MODE" ]; then
    echo "? Error: No mode specified. Usage: ./install.sh --ntfy | --webhost"
    exit 1
fi

echo "?? [$HOSTNAME] Starting Installation in $MODE mode..."

# 2. Save Server Identity (The "ID Card")
echo "$MODE" > ~/.gladstone_mode
echo "?? Server Identity set to: $MODE"

# 3. Core Dependency Installation
echo "?? Installing system dependencies..."
sudo apt update
sudo apt install -y jq curl git bc zip || echo "?? Package install warnings."

# 4. Mode-Specific Dependencies
if [ "$MODE" == "ntfy" ]; then
    echo "???  Installing Hub-specific tools (ntfy, speedtest)..."
    sudo apt install -y ntfy speedtest-cli
fi

# 5. Directory & Ownership Enforcement
echo "?? Enforcing Gladstone File Permissions & Ownership..."

# Ensure essential directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "/home/pi/printer_data"

# Ensure the 'pi' user owns the entire script tree to prevent log 'Permission Denied'
sudo chown -R $USER:$USER "$SCRIPT_DIR"

# Stage 1: Make all Shell scripts executable
chmod +x $SCRIPT_DIR/*.sh

# Stage 2: Ensure non-executables (configs, logs, backups) stay non-exec
chmod -x $SCRIPT_DIR/*.registry 2>/dev/null || true
chmod -x $SCRIPT_DIR/*.txt 2>/dev/null || true
chmod -x $SCRIPT_DIR/.gitignore 2>/dev/null || true
chmod 775 "$LOG_DIR"
chmod 775 "$BACKUP_DIR"
chmod 664 "$LOG_DIR"/*.log 2>/dev/null || true

# 6. Alias Injection (Persistent Command Access)
if ! grep -q "aliases.sh" ~/.bashrc; then
    echo "Adding Gladstone aliases to .bashrc..."
    echo "source $SCRIPT_DIR/aliases.sh" >> ~/.bashrc
fi

# 7. Hand-off to Mode-Aware Rebuild
if [ -f "$SCRIPT_DIR/pi_rebuild.sh" ]; then
    echo "??  Chaining to pi_rebuild.sh --$MODE..."
    bash "$SCRIPT_DIR/pi_rebuild.sh" "--$MODE"
else
    echo "? Error: pi_rebuild.sh not found. Setup incomplete."
    exit 1
fi

echo "-------------------------------------------------------"
echo "? [$HOSTNAME] Gladstone Installation Complete ($MODE)"
echo "?? Type 'refresh' or restart terminal to enable aliases."
echo "-------------------------------------------------------"