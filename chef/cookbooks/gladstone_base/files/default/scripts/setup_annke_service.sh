#!/bin/bash
# ==========================================================
# ANNKE EVENT LISTENER SETUP
# ==========================================================
# Installs dependencies and configures the ANNKE Event Listener
# as a systemd background service for the Hub.
# ==========================================================

# 1. Install dependencies
echo "📦 Installing Python dependencies..."
sudo apt-get update
sudo apt-get install -y python3-requests python3-pip

# As a fallback, ensure requests is available via pip if apt package fails or is too old
# --break-system-packages is required for PEP 668 on Debian 12+ if running global pip installs
sudo pip3 install requests --break-system-packages || sudo pip3 install requests

# 2. Setup Systemd Service
SERVICE_FILE="/etc/systemd/system/annke-listener.service"
SCRIPT_PATH="/home/gladstone/scripts/annke_event_listener.py"

echo "⚙️  Configuring systemd service..."

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ANNKE Camera Event Listener
After=network.target

[Service]
Type=simple
User=gladstone
ExecStart=/usr/bin/python3 $SCRIPT_PATH
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=annke-listener

[Install]
WantedBy=multi-user.target
EOF

# 3. Reload, Enable, and Start
echo "🚀 Reloading systemd daemon and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable annke-listener.service
sudo systemctl start annke-listener.service

echo "✅ ANNKE Event Listener service has been installed and started."
echo "📜 You can check the logs using: sudo journalctl -u annke-listener.service -f"
