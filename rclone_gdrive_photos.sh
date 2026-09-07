#!/bin/bash
# ==========================================================
# GLADSTONE GOOGLE DRIVE MEDIA SYNC (rclone_gdrive_photos.sh)
# ==========================================================
# PURPOSE:
# Mirrors a specific Google Drive folder ("Family Photos") to an
# external backup drive target on the NTFY Hub server.
#
# USAGE:
#   ./rclone_gdrive_photos.sh [OPTIONS]
#   Options:
#     --dry-run       Perform trial run with no changes made
#     --remote NAME   Override rclone remote source (Default: gdrive:Family Photos)
#     --target PATH   Override target destination directory
#     --verbose       Enable verbose rclone logging
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/rclone_gdrive_photos.log"
CONFIG_DIR="$HOME/.config/rclone"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
CONFIG_EXAMPLE="$CONFIG_DIR/rclone.conf.example"

HOSTNAME=$(hostname)
ALERT_TOPIC="ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"

mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"

log_msg() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# --- CLI ARGUMENT PARSING ---
DRY_RUN=0
VERBOSE=0
CUSTOM_REMOTE=""
CUSTOM_TARGET=""

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=1 ;;
        --verbose) VERBOSE=1 ;;
        --remote=*) CUSTOM_REMOTE="${arg#*=}" ;;
        --target=*) CUSTOM_TARGET="${arg#*=}" ;;
    esac
done

# Also check sequential positional flags if supplied
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote) CUSTOM_REMOTE="$2"; shift 2 ;;
        --target) CUSTOM_TARGET="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# --- LOCAL CONFIGURATION LOAD ---
ENV_FILE="$CONFIG_DIR/rclone_photos.env"

if [ ! -f "$ENV_FILE" ]; then
    cat << 'EOF' > "$ENV_FILE"
# Gladstone RClone Family Photos Sync Configuration
# PLEASE UPDATE THESE VALUES FOR YOUR SYNC TO WORK:

GDRIVE_REMOTE="gdrive:YOUR_REMOTE_FOLDER_NAME"
BACKUP_TARGET_DIR="/mnt/YOUR_BACKUP_DRIVE/family_photos"
EOF
    log_msg "WARNING" "RClone photos config missing. Created sample template at $ENV_FILE"
    if [ -z "$CUSTOM_REMOTE" ] && [ -z "$CUSTOM_TARGET" ]; then
        log_msg "ERROR" "❌ Please edit $ENV_FILE to set your Google Drive remote source and backup target path."
        curl -s -d "[$HOSTNAME] ⚠️ RClone photos config missing ($ENV_FILE). Please edit $ENV_FILE to set folder paths." "$ALERT_TOPIC" >/dev/null || true
        exit 1
    fi
fi

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Check if file still contains placeholder values
if [[ "$GDRIVE_REMOTE" == *"YOUR_REMOTE_FOLDER"* || "$BACKUP_TARGET_DIR" == *"YOUR_BACKUP_DRIVE"* ]]; then
    if [ -z "$CUSTOM_REMOTE" ] && [ -z "$CUSTOM_TARGET" ]; then
        log_msg "ERROR" "❌ Configuration file $ENV_FILE contains unconfigured sample placeholders."
        log_msg "ERROR" "Please run 'nano $ENV_FILE' to set your Google Drive remote source and target backup folder."
        curl -s -d "[$HOSTNAME] ⚠️ RClone photos config ($ENV_FILE) requires setup. Please update folder paths." "$ALERT_TOPIC" >/dev/null || true
        exit 1
    fi
fi

# Remote source resolution (CLI flag > local rclone_photos.env)
REMOTE_SRC="${CUSTOM_REMOTE:-$GDRIVE_REMOTE}"

# Target directory resolution (CLI flag > local rclone_photos.env)
TARGET_DIR="${CUSTOM_TARGET:-$BACKUP_TARGET_DIR}"

log_msg "INFO" "=========================================================="
log_msg "INFO" "Starting Google Drive 'Family Photos' RClone Mirror Sync"
log_msg "INFO" "Remote Source: $REMOTE_SRC"
log_msg "INFO" "Target Destination: $TARGET_DIR"

# Ensure rclone binary is installed
if ! command -v rclone &>/dev/null; then
    log_msg "ERROR" "rclone command not found. Please install rclone (sudo apt install -y rclone)."
    curl -s -d "[$HOSTNAME] ⚠️ RClone is not installed! Unable to run Family Photos sync." "$ALERT_TOPIC" >/dev/null || true
    exit 1
fi

# Ensure rclone config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_msg "WARNING" "RClone configuration file missing at $CONFIG_FILE."
    
    if [ ! -f "$CONFIG_EXAMPLE" ]; then
        cat << 'EOF' > "$CONFIG_EXAMPLE"
# Gladstone RClone Google Drive Configuration Template
# Run 'rclone config' on your Pi or populate this file with valid credentials.
#
# Example:
# [gdrive]
# type = drive
# client_id = 
# client_secret = 
# scope = drive.readonly
# token = {"access_token":"...","token_type":"Bearer","refresh_token":"...","expiry":"..."}
EOF
        log_msg "INFO" "Created template example config file at $CONFIG_EXAMPLE"
    fi

    log_msg "ERROR" "Please run 'rclone config' or configure $CONFIG_FILE to complete Google Drive authentication."
    curl -s -d "[$HOSTNAME] ⚠️ RClone config missing ($CONFIG_FILE). Please run 'rclone config' to pair Google Drive." "$ALERT_TOPIC" >/dev/null || true
    exit 1
fi

# Ensure target output folder exists
mkdir -p "$TARGET_DIR" 2>/dev/null || sudo mkdir -p "$TARGET_DIR" 2>/dev/null || true

# Prepare rclone flags
RCLONE_FLAGS=("--create-empty-src-dirs" "--transfers" "4" "--checkers" "8")
if [ "$DRY_RUN" -eq 1 ]; then
    RCLONE_FLAGS+=("--dry-run")
    log_msg "INFO" "Running in DRY-RUN mode."
fi
if [ "$VERBOSE" -eq 1 ]; then
    RCLONE_FLAGS+=("-vv" "--progress")
    log_msg "INFO" "Running in VERBOSE mode (-vv --progress)."
fi

log_msg "INFO" "Executing rclone sync..."
if [ "$VERBOSE" -eq 1 ]; then
    rclone sync "$REMOTE_SRC" "$TARGET_DIR" "${RCLONE_FLAGS[@]}" 2>&1 | tee -a "$LOG_FILE"
    SYNC_STATUS=${PIPESTATUS[0]}
else
    rclone sync "$REMOTE_SRC" "$TARGET_DIR" "${RCLONE_FLAGS[@]}" >> "$LOG_FILE" 2>&1
    SYNC_STATUS=$?
fi

if [ $SYNC_STATUS -eq 0 ]; then
    log_msg "INFO" "✅ Google Drive 'Family Photos' mirror sync completed successfully."
    curl -s -d "[$HOSTNAME] 📸 Google Drive 'Family Photos' mirror sync completed successfully." "$ALERT_TOPIC" >/dev/null || true
    exit 0
else
    log_msg "ERROR" "❌ Google Drive 'Family Photos' mirror sync failed (Exit Code: $SYNC_STATUS)."
    curl -s -d "[$HOSTNAME] ❌ Google Drive 'Family Photos' mirror sync failed (Exit Code: $SYNC_STATUS)." "$ALERT_TOPIC" >/dev/null || true
    exit $SYNC_STATUS
fi
