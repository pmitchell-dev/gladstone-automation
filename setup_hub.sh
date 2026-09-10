#!/bin/bash
# ==========================================================
# GLADSTONE HUB NODE SETUP (setup_hub.sh)
# ==========================================================
# Configures the Raspberry Pi 5 Hub Node via standard bash,
# bypassing the Chef ARM64 architecture limitation.
# Run with: sudo bash setup_hub.sh
# ==========================================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo bash setup_hub.sh)"
  exit 1
fi

echo "🚀 Starting Gladstone Hub Node Setup..."

# 1. Install Dependencies
echo "📦 Installing system dependencies..."
apt-get update -y
apt-get install -y jq curl git bc zip cifs-utils python3 smbclient rclone speedtest-cli

# 2. User Migration
if ! id "gladstone" &>/dev/null; then
  echo "👤 Creating 'gladstone' user..."
  useradd -m -s /bin/bash gladstone
  echo "gladstone:root" | chpasswd
  usermod -aG sudo gladstone
  echo "gladstone ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/gladstone
  chmod 0440 /etc/sudoers.d/gladstone
else
  echo "✅ User 'gladstone' already exists."
fi

# 3. Data Migration Hook
if [ -d "/home/pi" ]; then
  echo "🔄 Migrating data from /home/pi to /home/gladstone..."
  rsync -a --ignore-existing /home/pi/ /home/gladstone/
  chown -R gladstone:gladstone /home/gladstone
fi

# 4. Install Docker
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker gladstone
systemctl enable --now docker

# 5. Configure Cron Jobs for Hub Node
echo "⏱️ Configuring cron jobs..."
crontab -u gladstone -l 2>/dev/null | grep -v 'printer_health.sh' | grep -v 'net_speed.sh' | grep -v 'backup.sh' > /tmp/gladstone_cron
echo "0 */4 * * * /home/gladstone/scripts/printer_health.sh" >> /tmp/gladstone_cron
echo "0 */6 * * * /home/gladstone/scripts/net_speed.sh" >> /tmp/gladstone_cron
echo "0 0 * * * /home/gladstone/scripts/backup.sh" >> /tmp/gladstone_cron
crontab -u gladstone /tmp/gladstone_cron
rm /tmp/gladstone_cron

# 6. Configure Systemd Service
echo "⚙️ Configuring ntfy_listener systemd service..."
cat << 'EOF' > /etc/systemd/system/ntfy_listener.service
[Unit]
Description=ntfy Listener for Gladstone Hub
After=network.target

[Service]
ExecStart=/home/gladstone/scripts/ntfy_listener.sh
Restart=always
User=gladstone

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now ntfy_listener.service

echo "🎉 Gladstone Hub Node setup complete! Please log in as the 'gladstone' user and change your password."
