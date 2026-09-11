#!/bin/bash
# ==========================================================
# GLADSTONE PI 5 - DYNAMIC REPO UPDATER
# ==========================================================
# Dynamically finds and updates all git repositories in $HOME

echo "🔄 Scanning for Git repositories in $HOME (up to 3 levels deep)..."

# Find all .git directories in $HOME, max depth 3 to avoid scanning too deep or hitting permission errors
find "$HOME" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
    repo_dir=$(dirname "$gitdir")
    
    # Skip if we don't have read access
    if [ ! -r "$repo_dir" ]; then
        continue
    fi

    echo "----------------------------------------"
    echo "📁 Updating: $repo_dir"
    cd "$repo_dir" || continue
    
    # Check if there's a configured upstream remote
    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    
    if [ -n "$UPSTREAM" ]; then
        echo "⬇️  Force syncing with $UPSTREAM..."
        git fetch --all
        git reset --hard "$UPSTREAM"
        git clean -fd
    else
        echo "⚠️  Warning: No upstream tracking branch found in $repo_dir. Skipping."
    fi
done

echo "----------------------------------------"
echo "✅ All repositories updated!"
