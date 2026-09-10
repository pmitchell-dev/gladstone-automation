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
    
    # Check if there are unstaged changes before pulling to prevent errors
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️  Warning: Unstaged changes detected in $repo_dir. Stashing changes..."
        git stash
        git pull
        git stash pop || echo "⚠️  Warning: Merge conflict after stash pop in $repo_dir. Please check manually."
    else
        git pull
    fi
done

echo "----------------------------------------"
echo "✅ All repositories updated!"
