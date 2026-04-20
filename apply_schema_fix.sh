#!/bin/bash
# ==========================================================
# INVIDIOUS FORCE SCHEMA RESET (Feb 2026 Positional Fix)
# ==========================================================
# This script forcefully applies the 9-column schema fix to
# an existing Invidious database container.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/init-db.sql"

if [ ! -f "$SQL_FILE" ]; then
    echo "❌ Error: init-db.sql not found in $SCRIPT_DIR"
    exit 1
fi

echo "🔄 Locating Invidious Database container..."
# Try to find container by name pattern or compose label
DB_CONTAINER=$(docker ps --filter "name=invidious-db" --filter "status=running" -q | head -n 1)

if [ -z "$DB_CONTAINER" ]; then
    DB_CONTAINER=$(docker ps --filter "label=com.docker.compose.service=db" --filter "status=running" -q | head -n 1)
fi

if [ -z "$DB_CONTAINER" ]; then
    echo "❌ Error: Could not find a running Invidious DB container."
    echo "   Ensure your stack is running (docker compose up -d)"
    exit 1
fi

echo "✅ Found container: $DB_CONTAINER"
echo "⚠️  WARNING: This will DROP and RECREATE the 'users' table."
echo "   All local user data, subscriptions, and preferences will be ERASED."
echo "   Proceed? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "🚀 Applying schema fix..."
    cat "$SQL_FILE" | docker exec -i "$DB_CONTAINER" psql -U kemal -d invidious
    if [ $? -eq 0 ]; then
        echo "✨ Schema successfully updated! Please restart the Invidious container to be safe:"
        echo "   docker restart \$(docker ps --filter \"name=invidious-invidious\" -q)"
    else
        echo "❌ Error: SQL execution failed."
    fi
else
    echo "🚫 Operation cancelled."
fi
