#!/bin/bash
# ==========================================================
# GLADSTONE FAMILY PHOTOS ARCHIVER
# ==========================================================
# PURPOSE: Creates a compressed zip backup of family_photos.
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/archive_photos.log"
mkdir -p "$LOG_DIR"

# Verify the source directory exists
SOURCE_DIR="/mnt/backups/family_photos"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] family_photos directory not found at $SOURCE_DIR." | tee -a "$LOG_FILE"
    exit 1
fi

# Set destination directory to the local NVMe drive instead of the external drive
DEST_DIR="/home/gladstone/archives/family_photos_archives"
mkdir -p "$DEST_DIR"

DATE=$(date +"%Y-%m-%d")
ARCHIVE_NAME="family_photos_backup_${DATE}.zip"
DEST_FILE="$DEST_DIR/$ARCHIVE_NAME"

ALERT_TOPIC="https://ntfy.sh/patrick_mitch_pi5_x9k2v_alerts"
HOSTNAME=$(hostname)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting backup of $SOURCE_DIR to $DEST_FILE..." | tee -a "$LOG_FILE"
curl -s -d "[$HOSTNAME] 🗄️ Family Photos Archive started..." "$ALERT_TOPIC"

# Run zip
zip -r "$DEST_FILE" "$SOURCE_DIR" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] Backup completed: $DEST_FILE" | tee -a "$LOG_FILE"
    # Output the final size of the zip
    FILE_SIZE=$(du -sh "$DEST_FILE" | awk '{print $1}')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Archive size: $FILE_SIZE" | tee -a "$LOG_FILE"
    curl -s -d "[$HOSTNAME] ✅ Family Photos Archive completed ($FILE_SIZE)" "$ALERT_TOPIC"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Backup failed. Check logs at $LOG_FILE" | tee -a "$LOG_FILE"
    curl -s -H "Priority: high" -d "[$HOSTNAME] ❌ ERROR: Family Photos Archive failed" "$ALERT_TOPIC"
    exit 1
fi
