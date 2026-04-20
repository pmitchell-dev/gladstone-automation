#!/bin/bash
# ==========================================================
# INVIDIOUS CLEAN DB WIPE & RESET
# ==========================================================
# PURPOSE:
# Forces a complete zero-state reset of the Invidious database.
# This triggers the 'init-db.sql' script to run on next boot,
# ensuring the correct 2026 schema is applied.

INVID_DIR="/home/pi/invidious"

if [ ! -d "$INVID_DIR" ]; then
    echo "❌ Error: Invidious directory not found at $INVID_DIR"
    exit 1
fi

cd "$INVID_DIR" || exit

echo "🔄 Stopping Invidious stack..."
docker compose down

echo "⚠️  DANGER: This will permanently delete ALL user data."
echo "   Proceed with wipe? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚀 Wiping database volume..."
    sudo rm -rf postgresdata
    
    echo "🏗️  Rebuilding stack with clean schema..."
    docker compose up -d
    
    echo "✅ Wipe and Reset Complete!"
    echo "   Check database initialization logs with: docker compose logs db"
else
    echo "🚫 Operation cancelled."
    docker compose up -d
fi
