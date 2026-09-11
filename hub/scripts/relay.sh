#!/bin/bash
# ==========================================================
# GLADSTONE COMMUNICATION RELAY (v1.2)
# ==========================================================
# USAGE: relay [priority 1-5] "message"
# 5 = URGENT (Loud/Sticky) | 1 = MIN (Silent)
# ==========================================================

PRIORITY=$1
MESSAGE=$2
TOPIC="patrick_mitch_hub_x9k2v_alerts"

# Validate Priority input
if [[ ! "$PRIORITY" =~ ^[1-5]$ ]]; then
    echo "? Usage: relay [1-5] \"message\""
    exit 1
fi

# Auto-assign Tags based on Priority for visual scanning
case $PRIORITY in
    5) TAGS="skull,rotating_light,fire"; TITLE="?? FATAL ERROR" ;;
    4) TAGS="warning,bangbang"; TITLE="??  HIGH ALERT" ;;
    3) TAGS="white_check_mark,bell"; TITLE="?? INFO" ;;
    2) TAGS="speech_balloon,blue_book"; TITLE="?? LOW PRIORITY" ;;
    1) TAGS="ghost,zzz"; TITLE="?? DEBUG/MIN" ;;
esac

echo "???  Relaying Priority $PRIORITY to Gladstone Hub..."

NOW=$(date +%s)
MUTE_UNTIL=$(cat /tmp/gladstone_ntfy_mute 2>/dev/null || echo 0)
if [[ "$MUTE_UNTIL" =~ ^[0-9]+$ ]] && [ "$NOW" -lt "$MUTE_UNTIL" ]; then
    echo "🔕 Mute is active. Skipping relay."
    exit 0
fi

curl -H "Priority: $PRIORITY" \
     -H "Tags: $TAGS" \
     -H "Title: $TITLE ($HOSTNAME)" \
     -H "Actions: http, Mute rest of the day, https://ntfy.sh/patrick_mitch_hub_x9k2v_actions, method=POST, body=mute_watchdog" \
     -d "$MESSAGE" \
     "ntfy.sh/$TOPIC"

if [ $? -eq 0 ]; then
    echo "? Relay Successful."
else
    echo "? Relay Failed."
fi