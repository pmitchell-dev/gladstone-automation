#!/bin/bash

# ==========================================================
# GLADSTONE LOCAL ROTATION BACKUP (pi_backup.sh)
# ==========================================================
# PURPOSE:
# Creates a zipped backup of the ~/scripts folder.
# Maintains a strict rotation of only the 2 most recent backups.
# ==========================================================

SOURCE_DIR="/home/pi/scripts"
BACKUP_DIR="$SOURCE_DIR/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gladstone_backup_$TIMESTAMP.zip"

# 1. Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "📦 Creating Gladstone backup: $BACKUP_NAME"

# 2. Create the ZIP (Excluding the backup and logs folders to save space/recursion)
# We use -r for recursive and -q for quiet
zip -rq "$BACKUP_DIR/$BACKUP_NAME" "$SOURCE_DIR" -x "$SOURCE_DIR/backup/*" "$SOURCE_DIR/logs/*"

if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully."
else
    echo "❌ Backup failed."
    exit 1
fi

if [ -d "/home/pi/homeasset/data" ]; then
    echo "?? Backing up HomeAsset Data..."
    cp -r /home/pi/homeasset/data /home/pi/scripts/backup/homeasset_data_$(date +%F)
fi

if [ -d "/home/pi/invidious" ]; then
    echo "?? Backing up Invidious Config and Data..."
    cp -r /home/pi/invidious /home/pi/scripts/backup/invidious_backup_$(date +%F)
fi


# 3. Rotation Logic: Keep only the 2 most recent files
# ls -t lists by time (newest first). tail -n +3 selects everything after the 2nd file.
echo "Cleaning up old backups (keeping top 2)..."
ls -t "$BACKUP_DIR"/gladstone_backup_*.zip 2>/dev/null | tail -n +3 | xargs -I {} rm {}

echo "📋 Current backups in storage:"
ls -lh "$BACKUP_DIR"
