# --- Master Aliases (Synced via GitHub) ---

# The Magic Sync
alias sync='bash $HOME/scripts/sync_repo.sh'

# Navigation Helpers
alias sc='cd ~/scripts'
alias home='cd ~'

# Quick Logs
alias nlog='tail -f ~/ntfy.log'
alias slog='tail -f ~/services_manager.log'

# System
alias lsa='ls -lah'
alias update='sudo apt update && sudo apt upgrade -y'
alias cycle='pkill -f ntfy_listener.sh && nohup bash $HOME/scripts/ntfy_listener.sh > $HOME/ntfy.log 2>&1 & echo "🔄 Listener Cycled."' 
