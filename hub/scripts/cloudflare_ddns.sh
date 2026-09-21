#!/bin/bash

# ==========================================================
# Cloudflare DDNS Updater for Hub Server
# ==========================================================
# Reads configuration from .env.cloudflare in the same directory.
# Required variables in .env.cloudflare:
# CF_API_TOKEN="your_cloudflare_api_token"
# CF_ZONE_ID="your_zone_id"
# CF_RECORD_NAME="rustdesk.dark-ops.cc"
# ==========================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ENV_FILE="$DIR/.env.cloudflare"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Configuration file $ENV_FILE not found."
    exit 1
fi

source "$ENV_FILE"

if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$CF_RECORD_NAME" ]; then
    echo "Error: Missing required variables in $ENV_FILE"
    exit 1
fi

# Get current public IP
CURRENT_IP=$(curl -s -4 https://ifconfig.me || curl -s -4 https://api.ipify.org)

if [ -z "$CURRENT_IP" ]; then
    echo "Error: Could not retrieve current public IP."
    exit 1
fi

# Get the DNS record ID and current IP from Cloudflare
RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD_NAME" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json")

# Check if the API call was successful
SUCCESS=$(echo "$RECORD_INFO" | grep -o '"success":true')
if [ -z "$SUCCESS" ]; then
    echo "Error: Failed to fetch DNS record info from Cloudflare API."
    echo "$RECORD_INFO"
    exit 1
fi

# Extract Record ID and existing IP using simple grep/sed (avoiding jq dependency on Hub)
RECORD_ID=$(echo "$RECORD_INFO" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
DNS_IP=$(echo "$RECORD_INFO" | grep -o '"content":"[^"]*' | head -n1 | cut -d'"' -f4)

if [ -z "$RECORD_ID" ]; then
    echo "Error: Could not find DNS record ID for $CF_RECORD_NAME. Does it exist?"
    exit 1
fi

if [ "$CURRENT_IP" == "$DNS_IP" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No change needed. IP is still $CURRENT_IP."
    exit 0
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - IP changed from $DNS_IP to $CURRENT_IP. Updating Cloudflare..."

# Update the DNS record
UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"'"$CF_RECORD_NAME"'","content":"'"$CURRENT_IP"'","ttl":1,"proxied":false}')

UPDATE_SUCCESS=$(echo "$UPDATE_RESULT" | grep -o '"success":true')

if [ -n "$UPDATE_SUCCESS" ]; then
    echo "Successfully updated $CF_RECORD_NAME to $CURRENT_IP"
else
    echo "Failed to update DNS record!"
    echo "$UPDATE_RESULT"
    exit 1
fi
