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

# Listener Cycle Function
cycle() {
    echo "🔄 Cycling ntfy listener..."
    pkill -f ntfy_listener.sh
    nohup bash /home/pi/scripts/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &
    sleep 1
    NEW_PID=$(pgrep -f ntfy_listener.sh)
    echo "✅ Listener restarted. (PID: $NEW_PID)"
}
