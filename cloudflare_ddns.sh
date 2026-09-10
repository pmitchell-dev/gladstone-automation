#!/bin/bash
# ==========================================================
# GLADSTONE CLOUDFLARE DYNAMIC DNS UPDATER (cloudflare_ddns.sh)
# ==========================================================
# Automatically checks public WAN IP and updates Cloudflare A record.
# Config file: ~/.cloudflare_ddns.env
# ==========================================================

SCRIPT_DIR="$HOME/scripts"
LOG_FILE="$SCRIPT_DIR/logs/cloudflare_ddns.log"
CONFIG_FILE="$HOME/.cloudflare_ddns.env"
mkdir -p "$SCRIPT_DIR/logs"

# Ensure config exists
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
# Cloudflare DDNS Configuration
CF_API_TOKEN="cfat_23TbRjWF08Dl33drYPP16E8UbO6QUAn1E5RTCe0l4d26dac6"
CF_ZONE_ID="5923158ae66e495746c3474e4e87dadc"
CF_RECORD_NAME="localrepo.net"
EOF
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔑 Config file created at $CONFIG_FILE with pre-configured Cloudflare credentials." >> "$LOG_FILE"
fi

source "$CONFIG_FILE"

if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏸️ Skipping Cloudflare DDNS update (CF_API_TOKEN or CF_ZONE_ID not configured)." >> "$LOG_FILE"
    exit 0
fi

# Fetch current public WAN IP
CURRENT_IP=$(curl -s --max-time 10 https://api.ipify.org || curl -s --max-time 10 https://ifconfig.me)

if [[ -z "$CURRENT_IP" || ! "$CURRENT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to retrieve valid public IP address." >> "$LOG_FILE"
    exit 1
fi

# Check last cached IP to prevent spamming API
CACHE_FILE="/tmp/gladstone_last_ddns_ip"
LAST_IP=$(cat "$CACHE_FILE" 2>/dev/null)

if [ "$CURRENT_IP" == "$LAST_IP" ]; then
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 WAN IP change detected ($LAST_IP -> $CURRENT_IP). Triggering OpenTofu Apply..." >> "$LOG_FILE"

cd "$SCRIPT_DIR/tofu"
tofu apply -var="wan_ip=$CURRENT_IP" -target=module.cloudflare -auto-approve >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "$CURRENT_IP" > "$CACHE_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Successfully updated Cloudflare via OpenTofu to $CURRENT_IP." >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to update Cloudflare via OpenTofu." >> "$LOG_FILE"
fi
