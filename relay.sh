#!/bin/bash
# ==========================================================
# GLADSTONE COMMUNICATION RELAY (relay.sh)
# ==========================================================
# PURPOSE: 
# A shorthand tool to send formatted ntfy messages to 
# specific Gladstone channels.
# 
# USAGE: 
# relay [topic_suffix] [priority] "message"
# Example: relay alerts high "Printer is on fire!"
# ==========================================================

SUFFIX=$1   # alerts, vitals, track, webhost
PRIORITY=$2 # min, low, default, high, urgent
MESSAGE=$3

# Mapping suffixes to your master topic base
BASE_TOPIC="patrick_mitch_pi5_x9k2v"
TARGET_TOPIC="${BASE_TOPIC}_${SUFFIX}"

if [ -z "$MESSAGE" ]; then
    echo "❌ Usage: relay [suffix] [priority] \"message\""
    exit 1
fi

echo "🛰️  Relaying to $TARGET_TOPIC..."

curl -H "Priority: $PRIORITY" \
     -H "Title: Gladstone Relay ($HOSTNAME)" \
     -d "$MESSAGE" \
     "ntfy.sh/$TARGET_TOPIC"

if [ $? -eq 0 ]; then
    echo "✅ Message sent."
else
    echo "❌ Failed to send message."
fi
