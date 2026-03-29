#!/bin/bash
# ==========================================================
# GLADSTONE COMMUNICATION RELAY (v1.2)
# ==========================================================
# USAGE: relay [priority 1-5] "message"
# 5 = URGENT (Loud/Sticky) | 1 = MIN (Silent)
# ==========================================================

PRIORITY=$1
MESSAGE=$2
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

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

curl -H "Priority: $PRIORITY" \
     -H "Tags: $TAGS" \
     -H "Title: $TITLE ($HOSTNAME)" \
     -d "$MESSAGE" \
     "ntfy.sh/$TOPIC"

if [ $? -eq 0 ]; then
    echo "? Relay Successful."
else
    echo "? Relay Failed."
fi