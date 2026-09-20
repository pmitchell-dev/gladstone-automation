#!/bin/bash

# ==========================================================
# GLADSTONE PI 5 OFFICIAL ALIASES & UTILITIES (v1.7)
# ==========================================================

SCRIPT_DIR="$HOME/scripts"

# --- DASHBOARD & MONITORING ---
if [ -f "$HOME/.gladstone_mode" ] && grep -q "webhost" "$HOME/.gladstone_mode"; then
    alias db="bash $SCRIPT_DIR/webhost-dashboard.sh"
    alias dashboard="bash $SCRIPT_DIR/webhost-dashboard.sh"
else
    alias db="bash $SCRIPT_DIR/dashboard.sh"
    alias dashboard="bash $SCRIPT_DIR/dashboard.sh"
fi

# --- MAINTENANCE & RECOVERY ---
alias run-chef='cd ~/gladstone-automation && git pull && cd chef && sudo chef-client -z -r "recipe[gladstone_base::default],recipe[gladstone_webhost::default]"'
alias run-terraform='cd ~/gladstone-automation && git pull && cd terraform && terraform apply'
alias update-repos="bash $SCRIPT_DIR/update_repos.sh"
alias fresh-install="cd ~ && rm -rf ~/gladstone-automation && git clone https://github.com/pmitchell-dev/gladstone-automation.git ~/gladstone-automation && cd ~/gladstone-automation/chef && sudo chef-client -z"
alias fresh-reinstall="cd ~ && rm -rf ~/gladstone-automation && git clone https://github.com/pmitchell-dev/gladstone-automation.git ~/gladstone-automation && cd ~/gladstone-automation/chef && sudo chef-client -z"
alias git-install="cd ~ && rm -rf ~/gladstone-automation && git clone https://github.com/pmitchell-dev/gladstone-automation.git ~/gladstone-automation && cd ~/gladstone-automation/chef && sudo chef-client -z"
alias backup="bash $SCRIPT_DIR/backup.sh"
alias restore="bash $SCRIPT_DIR/restore.sh"
alias sync-photos="bash $SCRIPT_DIR/rclone_gdrive_photos.sh"
alias photos-sync="bash $SCRIPT_DIR/rclone_gdrive_photos.sh"
alias google_update="bash $SCRIPT_DIR/rclone_gdrive_photos.sh"
alias features="bash $SCRIPT_DIR/features.sh"
alias pi-features="bash $SCRIPT_DIR/features.sh"
alias refresh='source ~/.bashrc && echo "🔄 Environment refreshed."'

# --- COMMUNICATION & SERVICES ---
# Shorthand for the relay script
alias relay="bash $SCRIPT_DIR/relay.sh"

# cycle: Restarts the ntfy listener using the standard log path
cycle() {
    echo "?? Cycling Listener..."
    pkill -f ntfy_listener.sh
    sleep 1
    nohup /bin/bash "$SCRIPT_DIR/ntfy_listener.sh" > "$SCRIPT_DIR/logs/ntfy.log" 2>&1 &
    echo "? Listener restarted. Logging to $SCRIPT_DIR/logs/ntfy.log"
}
