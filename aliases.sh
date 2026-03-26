# --- Gladstone Pi 5 Official Aliases ---
alias db='/home/pi/scripts/pi-dashboard.sh'
alias dashboard='/home/pi/scripts/pi-dashboard.sh'
alias sync='bash /home/pi/scripts/pi_sync.sh'
alias rebuild='bash /home/pi/scripts/pi_rebuild.sh'
alias reinstall='bash /home/pi/scripts/pi_rebuild.sh'
alias sniff='bash /home/pi/scripts/sniffspot_check.sh'

# Listener Cycle Function
cycle() {
    echo "🔄 Cycling ntfy listener..."
    pkill -f ntfy_listener.sh
    sleep 1
    nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &
    echo "✅ Listener restarted. (PID: $(pgrep -f ntfy_listener.sh))"
}
