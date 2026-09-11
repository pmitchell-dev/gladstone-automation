#!/bin/bash
# Install script for ntfy_listener.sh systemd service on the Hub

SERVICE_FILE="/etc/systemd/system/ntfy_listener.service"

echo "🛠️ Creating systemd service for ntfy_listener at $SERVICE_FILE..."

sudo bash -c "cat > $SERVICE_FILE" << 'EOF'
[Unit]
Description=Gladstone NTFY Listener
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=gladstone
ExecStart=/bin/bash /home/gladstone/scripts/ntfy_listener.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "🚀 Enabling and starting ntfy_listener service..."
sudo systemctl enable --now ntfy_listener.service

echo "✅ ntfy_listener is now running as a background service!"
echo "You can check its status anytime with: sudo systemctl status ntfy_listener"
echo "You can view its live logs with: sudo journalctl -fu ntfy_listener"
