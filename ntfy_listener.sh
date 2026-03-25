#!/bin/bash
# Agnostic NTFY Listener - Works for any user/host
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
SCRIPT_DIR="$HOME/scripts"

ntfy subscribe $TOPIC | while read -r line; do
  RAW_MSG=$(echo "$line" | jq -r '.message' 2>/dev/null)
  MSG_LOWER=$(echo "$RAW_MSG" | tr '[:upper:]' '[:lower:]' | xargs)

  # --- COMMAND: help ---
  if [[ "$MSG_LOWER" == "help" ]]; then
      HELP_MSG="📖 $HOSTNAME COMMAND GUIDE
----------------------
🖨️ PRINTER: health
✈️ FLIGHTS: flight [ID] | stop [ID]
📊 SYSTEM: status | sync | alert
🛠️ ADMIN: reinstall | reboot

🔥 RECOVERY (SCRATCH):
git clone https://github.com/legendary034/pi5-scripts.git ~/scripts && bash ~/scripts/install.sh
----------------------"
      curl -H "Title: Command Help" -H "Tags: bookshelf" -d "$HELP_MSG" ntfy.sh/$TOPIC > /dev/null

  # --- COMMAND: reinstall ---
  elif [[ "$MSG_LOWER" == "reinstall" ]]; then
      curl -d "⚙️ Running Rebuild on $HOSTNAME..." ntfy.sh/$TOPIC
      bash "$SCRIPT_DIR/pi_rebuild.sh"
      curl -d "✅ Reinstall Complete!" ntfy.sh/$TOPIC

  # --- COMMAND: flight [ID] ---
  elif [[ $MSG_LOWER == flight* ]]; then
      FLIGHT_ID=$(echo "$RAW_MSG" | awk '{print $2}')
      bash "$SCRIPT_DIR/track_flight.sh" "$FLIGHT_ID" & disown
  
  # --- COMMAND: stop [ID] ---
  elif [[ $MSG_LOWER == stop* ]]; then
      FLIGHT_ID=$(echo "$RAW_MSG" | awk '{print $2}' | tr '[:lower:]' '[:upper:]')
      pkill -f "track_flight.sh $FLIGHT_ID"
      curl -s -d "🛑 Stopped tracking $FLIGHT_ID on $HOSTNAME" ntfy.sh/$TOPIC > /dev/null

  # --- OTHER ALIASES ---
  else
      case "$MSG_LOWER" in
        "health") bash "$SCRIPT_DIR/get_printer_status.sh" && bash "$SCRIPT_DIR/printer_alert.sh" manual ;;
        "status") bash "$SCRIPT_DIR/pi-dashboard.sh" push ;;
        "alert")  curl -d "$HOSTNAME Connection OK! 🚀" ntfy.sh/$TOPIC ;;
        "reboot") curl -d "♻️ Rebooting $HOSTNAME..." ntfy.sh/$TOPIC; sleep 2; sudo reboot ;;
      esac
  fi
done
