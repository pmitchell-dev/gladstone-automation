#!/bin/bash
# ==========================================================
# GLADSTONE GOOGLE DRIVE MEDIA SYNC (rclone_gdrive_photos.sh)
# ==========================================================
# PURPOSE:
# Mirrors a specific local media folder (e.g. external backup drive)
# UP TO a Google Drive remote folder (Local -> Google Drive).
#
# USAGE:
#   ./rclone_gdrive_photos.sh [OPTIONS]
#   Options:
#     --dry-run       Perform trial run with no changes made
#     --remote NAME   Override rclone remote destination (Default: gdrive:Family Photos)
#     --source PATH   Override local source directory
#     --verbose       Enable verbose rclone logging
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/rclone_gdrive_photos.log"
CONFIG_DIR="$HOME/.config/rclone"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
CONFIG_EXAMPLE="$CONFIG_DIR/rclone.conf.example"

HOSTNAME=$(hostname)
ALERT_TOPIC="https://ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"

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
CUSTOM_LOCAL=""

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=1 ;;
        --verbose|-v) VERBOSE=1 ;;
        --remote=*) CUSTOM_REMOTE="${arg#*=}" ;;
        --source=*) CUSTOM_LOCAL="${arg#*=}" ;;
    esac
done

# Also check sequential positional flags if supplied
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote) CUSTOM_REMOTE="$2"; shift 2 ;;
        --source) CUSTOM_LOCAL="$2"; shift 2 ;;
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
    if [ -z "$CUSTOM_REMOTE" ] && [ -z "$CUSTOM_LOCAL" ]; then
        log_msg "ERROR" "❌ Please edit $ENV_FILE to set your Google Drive remote destination and local source path."
        curl -s -d "[$HOSTNAME] ⚠️ RClone photos config missing ($ENV_FILE). Please edit $ENV_FILE to set folder paths." "$ALERT_TOPIC" >/dev/null || true
        exit 1
    fi
fi

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Check if file still contains placeholder values
if [[ "$GDRIVE_REMOTE" == *"YOUR_REMOTE_FOLDER"* || "$BACKUP_TARGET_DIR" == *"YOUR_BACKUP_DRIVE"* ]]; then
    if [ -z "$CUSTOM_REMOTE" ] && [ -z "$CUSTOM_LOCAL" ]; then
        log_msg "ERROR" "❌ Configuration file $ENV_FILE contains unconfigured sample placeholders."
        log_msg "ERROR" "Please run 'nano $ENV_FILE' to set your Google Drive remote destination and local source folder."
        curl -s -d "[$HOSTNAME] ⚠️ RClone photos config ($ENV_FILE) requires setup. Please update folder paths." "$ALERT_TOPIC" >/dev/null || true
        exit 1
    fi
fi

# Remote destination resolution (CLI flag > local rclone_photos.env)
REMOTE_DEST="${CUSTOM_REMOTE:-$GDRIVE_REMOTE}"

# Local source directory resolution (CLI flag > local rclone_photos.env)
LOCAL_SRC="${CUSTOM_LOCAL:-$BACKUP_TARGET_DIR}"

# Ensure both paths are configured
if [ -z "$REMOTE_DEST" ] || [ -z "$LOCAL_SRC" ]; then
    log_msg "ERROR" "❌ Configuration missing: Remote destination or local source is empty."
    log_msg "ERROR" "Please check $ENV_FILE and ensure GDRIVE_REMOTE and BACKUP_TARGET_DIR are properly set."
    curl -s -d "[$HOSTNAME] ⚠️ RClone photos config ($ENV_FILE) is missing required variables." "$ALERT_TOPIC" >/dev/null || true
    exit 1
fi

# Patrick and Torrey sync resolution
REMOTE_ROOT="${REMOTE_DEST%:*}"
REMOTE_PT_DEST="${REMOTE_ROOT}:Patrick and Torrey"
LOCAL_PT_SRC="$(dirname "$LOCAL_SRC")/patrick_and_torrey"

log_msg "INFO" "=========================================================="
log_msg "INFO" "Starting Google Drive 'Family Photos' RClone One-Way Sync"
log_msg "INFO" "Local Source: $LOCAL_SRC"
log_msg "INFO" "Remote Destination: $REMOTE_DEST"
log_msg "INFO" "----------------------------------------------------------"
log_msg "INFO" "Starting Google Drive 'Patrick and Torrey' RClone One-Way Sync"
log_msg "INFO" "Local Source: $LOCAL_PT_SRC"
log_msg "INFO" "Remote Destination: $REMOTE_PT_DEST"

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

# Ensure log directory exists and is writable
mkdir -p "$LOG_DIR" 2>/dev/null || true
if [ ! -w "$LOG_DIR" ]; then
    echo "ERROR: Log directory ($LOG_DIR) is not writable by $USER." >&2
    exit 1
fi

# Ensure local source folder exists
if [ ! -d "$LOCAL_SRC" ]; then
    mkdir -p "$LOCAL_SRC" 2>/dev/null || true
fi

if [ ! -d "$LOCAL_SRC" ] || [ ! -r "$LOCAL_SRC" ]; then
    log_msg "ERROR" "❌ Local source directory $LOCAL_SRC does not exist or is not readable by user $USER."
    log_msg "ERROR" "Please verify source folder permissions or create it."
    curl -s -d "[$HOSTNAME] ⚠️ RClone photo sync source path ($LOCAL_SRC) is not readable!" "$ALERT_TOPIC" >/dev/null || true
    exit 1
fi

# Prepare rclone flags
RCLONE_FLAGS=("--create-empty-src-dirs" "--transfers" "4" "--checkers" "8" "--size-only")
if [ "$DRY_RUN" -eq 1 ]; then
    RCLONE_FLAGS+=("--dry-run")
    log_msg "INFO" "Running in DRY-RUN mode."
fi
if [ "$VERBOSE" -eq 1 ]; then
    RCLONE_FLAGS+=("-vv" "--progress")
    log_msg "INFO" "Running in VERBOSE mode (-vv --progress)."
fi

log_msg "INFO" "Executing rclone sync (Local -> Remote)..."
if [ "$VERBOSE" -eq 1 ]; then
    rclone sync "$LOCAL_SRC" "$REMOTE_DEST" "${RCLONE_FLAGS[@]}" 2>&1 | tee -a "$LOG_FILE"
    SYNC_STATUS=${PIPESTATUS[0]}
else
    rclone sync "$LOCAL_SRC" "$REMOTE_DEST" "${RCLONE_FLAGS[@]}" >> "$LOG_FILE" 2>&1
    SYNC_STATUS=$?
fi

if [ $SYNC_STATUS -eq 0 ]; then
    log_msg "INFO" "✅ Google Drive 'Family Photos' sync completed successfully."
    curl -s -d "[$HOSTNAME] 📸 Google Drive 'Family Photos' sync completed successfully." "$ALERT_TOPIC" >/dev/null || true
else
    log_msg "ERROR" "❌ Google Drive 'Family Photos' sync failed (Exit Code: $SYNC_STATUS)."
    curl -s -d "[$HOSTNAME] ❌ Google Drive 'Family Photos' sync failed (Exit Code: $SYNC_STATUS)." "$ALERT_TOPIC" >/dev/null || true
    exit $SYNC_STATUS
fi

log_msg "INFO" "----------------------------------------------------------"
log_msg "INFO" "Executing rclone sync for 'Patrick and Torrey' (Local -> Remote)..."

# Ensure local source folder exists for Patrick and Torrey
if [ ! -d "$LOCAL_PT_SRC" ]; then
    mkdir -p "$LOCAL_PT_SRC" 2>/dev/null || true
fi

if [ ! -d "$LOCAL_PT_SRC" ] || [ ! -r "$LOCAL_PT_SRC" ]; then
    log_msg "ERROR" "❌ Local source directory $LOCAL_PT_SRC does not exist or is not readable by user $USER."
    curl -s -d "[$HOSTNAME] ⚠️ RClone photo sync source path ($LOCAL_PT_SRC) is not readable!" "$ALERT_TOPIC" >/dev/null || true
    exit 1
fi

if [ "$VERBOSE" -eq 1 ]; then
    rclone sync "$LOCAL_PT_SRC" "$REMOTE_PT_DEST" "${RCLONE_FLAGS[@]}" 2>&1 | tee -a "$LOG_FILE"
    SYNC_STATUS_PT=${PIPESTATUS[0]}
else
    rclone sync "$LOCAL_PT_SRC" "$REMOTE_PT_DEST" "${RCLONE_FLAGS[@]}" >> "$LOG_FILE" 2>&1
    SYNC_STATUS_PT=$?
fi

if [ $SYNC_STATUS_PT -eq 0 ]; then
    log_msg "INFO" "✅ Google Drive 'Patrick and Torrey' sync completed successfully."
    curl -s -d "[$HOSTNAME] 📸 Google Drive 'Patrick and Torrey' sync completed successfully." "$ALERT_TOPIC" >/dev/null || true
    exit 0
else
    log_msg "ERROR" "❌ Google Drive 'Patrick and Torrey' sync failed (Exit Code: $SYNC_STATUS_PT)."
    curl -s -d "[$HOSTNAME] ❌ Google Drive 'Patrick and Torrey' sync failed (Exit Code: $SYNC_STATUS_PT)." "$ALERT_TOPIC" >/dev/null || true
    exit $SYNC_STATUS_PT
fi
