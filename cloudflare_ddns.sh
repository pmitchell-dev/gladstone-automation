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

update_record() {
    local ZONE_ID=$1
    local RECORD_NAME=$2
    
    # Get the DNS record ID and current IP from Cloudflare
    local RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$RECORD_NAME" \
         -H "Authorization: Bearer $CF_API_TOKEN" \
         -H "Content-Type: application/json")

    # Check if the API call was successful
    local SUCCESS=$(echo "$RECORD_INFO" | grep -o '"success":true')
    if [ -z "$SUCCESS" ]; then
        echo "Error: Failed to fetch DNS record info from Cloudflare API for $RECORD_NAME."
        echo "$RECORD_INFO"
        return 1
    fi

    # Extract Record ID and existing IP using simple grep/sed (avoiding jq dependency on Hub)
    local RECORD_ID=$(echo "$RECORD_INFO" | grep -o '"id":"[^"]*' | head -n1 | cut -d'"' -f4)
    local DNS_IP=$(echo "$RECORD_INFO" | grep -o '"content":"[^"]*' | head -n1 | cut -d'"' -f4)

    if [ -z "$RECORD_ID" ]; then
        echo "Error: Could not find DNS record ID for $RECORD_NAME. Does it exist?"
        return 1
    fi

    if [ "$CURRENT_IP" == "$DNS_IP" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No change needed for $RECORD_NAME. IP is still $CURRENT_IP."
        return 0
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - IP changed from $DNS_IP to $CURRENT_IP for $RECORD_NAME. Updating Cloudflare..."

    # Update the DNS record
    local UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
         -H "Authorization: Bearer $CF_API_TOKEN" \
         -H "Content-Type: application/json" \
         --data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$CURRENT_IP"'","ttl":1,"proxied":false}')

    local UPDATE_SUCCESS=$(echo "$UPDATE_RESULT" | grep -o '"success":true')

    if [ -n "$UPDATE_SUCCESS" ]; then
        echo "Successfully updated $RECORD_NAME to $CURRENT_IP"
    else
        echo "Failed to update DNS record for $RECORD_NAME!"
        echo "$UPDATE_RESULT"
        return 1
    fi
}

# Update primary record
update_record "$CF_ZONE_ID" "$CF_RECORD_NAME"

# Update secondary record if configured
if [ -n "$CF_ZONE_ID_2" ] && [ -n "$CF_RECORD_NAME_2" ]; then
    update_record "$CF_ZONE_ID_2" "$CF_RECORD_NAME_2"
fi
