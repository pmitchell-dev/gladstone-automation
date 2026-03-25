#!/bin/bash
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

ntfy subscribe $TOPIC | while read -r line; do
  RAW_MSG=$(echo "$line" | jq -r '.message' 2>/dev/null)
  MSG_LOWER=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]' | xargs)

  # --- COMMAND: help ---
  if [[ "$MSG_LOWER" == "help" ]]; then
      HELP_MSG="📖 RPI5 COMMAND GUIDE
----------------------
🖨️ PRINTER
- health : Full Toner/Status

✈️ FLIGHTS
- flight [ID] : Start tracking
- stop [ID]   : Stop tracking

📊 SYSTEM
- status : Get live Dashboard
- alert  : Connection Ping

🛠️ ADMIN
- reboot : Restart the Pi
----------------------"
      curl -H "Title: Command Help" -H "Tags: bookshelf" -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null

  # --- COMMAND: flight [ID] ---
  elif [[ $MSG_LOWER == flight* ]]; then
      FLIGHT_ID=$(echo "$RAW_MSG" | awk '{print $2}')
      /home/pi/track_flight.sh "$FLIGHT_ID" & disown
  
  # --- COMMAND: stop [ID] ---
  elif [[ $MSG_LOWER == stop* ]]; then
      FLIGHT_ID=$(echo "$RAW_MSG" | awk '{print $2}' | tr '[:lower:]' '[:upper:]')
      pkill -f "track_flight.sh $FLIGHT_ID"
      curl -s -d "🛑 Stopped tracking $FLIGHT_ID" ntfy.sh/$TOPIC > /dev/null

  # --- OTHER ALIASES ---
  else
      case "$MSG_LOWER" in
        "health") /home/pi/get_printer_status.sh && /home/pi/printer_alert.sh manual ;;
        "status") /home/pi/pi-dashboard.sh push ;;
        "alert")  curl -d "Pi 5 Connection OK! 🚀" ntfy.sh/$TOPIC ;;
        "reboot") curl -d "♻️ Rebooting Pi 5..." ntfy.sh/$TOPIC; sleep 2; sudo reboot ;;
      esac
  fi
done
