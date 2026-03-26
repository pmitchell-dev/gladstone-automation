#!/bin/bash
exec > >(tee -a /home/pi/rebuild.log) 2>&1
# Gladstone Full System Provisioner
echo "🛠️ Rebuilding Gladstone Environment..."

# 1. Install Architecture-Specific Packages
if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "💻 x86 detected. Installing laptop support tools..."
    sudo apt update && sudo apt install -y lm-sensors htop jq curl git
    sudo sensors-detect --auto > /dev/null
else
    echo "🍓 Raspberry Pi detected. Installing Pi support tools..."
    sudo apt update && sudo apt install -y jq curl git
fi

# 2. Setup Directory Structure
mkdir -p /home/pi/scripts
mkdir -p /home/pi/printer_data

# 3. Setup Aliases
bash /home/pi/scripts/aliases.sh

# 4. Schedule the Printer Scraper (8am-8pm hourly)
(crontab -l 2>/dev/null | grep -v "printer"; echo "0 8-20 * * * /home/pi/scripts/printer_health.sh") | crontab -

# 5. Start the Listener in the background
pkill -f ntfy_listener.sh
nohup /bin/bash /home/pi/scripts/ntfy_listener.sh > /home/pi/ntfy.log 2>&1 &

echo "✅ Rebuild Complete. Type 'db' to view status."
