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
CF_API_TOKEN=""
CF_ZONE_ID=""
CF_RECORD_NAME="localrepo.net"
EOF
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Config file created at $CONFIG_FILE. Please add your CF_API_TOKEN and CF_ZONE_ID." >> "$LOG_FILE"
    exit 0
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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 WAN IP change detected ($LAST_IP -> $CURRENT_IP). Fetching Cloudflare Record ID for $CF_RECORD_NAME..." >> "$LOG_FILE"

# Query Cloudflare API for Record ID
RECORD_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json")

RECORD_ID=$(echo "$RECORD_RESP" | jq -r '.result[0].id // empty')

if [ -z "$RECORD_ID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Cloudflare DNS A record for $CF_RECORD_NAME not found." >> "$LOG_FILE"
    exit 1
fi

# Update Cloudflare A Record
UPDATE_RESP=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}")

SUCCESS=$(echo "$UPDATE_RESP" | jq -r '.success')

if [ "$SUCCESS" == "true" ]; then
    echo "$CURRENT_IP" > "$CACHE_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Successfully updated Cloudflare $CF_RECORD_NAME to $CURRENT_IP." >> "$LOG_FILE"
else
    ERRORS=$(echo "$UPDATE_RESP" | jq -r '.errors[0].message // "Unknown error"')
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Failed to update Cloudflare DNS: $ERRORS" >> "$LOG_FILE"
fi
