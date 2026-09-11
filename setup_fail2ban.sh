#!/bin/bash
# setup_fail2ban.sh
# Installation and hardening script for Fail2ban on Debian 13 (Trixie)

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo ./setup_fail2ban.sh)"
  exit 1
fi

echo "=========================================="
echo " Starting Fail2ban Setup for Hub & Spoke  "
echo "=========================================="

echo "[1/4] Updating package lists..."
apt-get update -y

echo "[2/4] Installing fail2ban..."
apt-get install -y fail2ban

echo "[3/4] Configuring SSH Jail..."
# We create a jail.local file which overrides defaults and won't be overwritten on package updates.
cat << 'EOF' > /etc/fail2ban/jail.local
[DEFAULT]
# Ban IP for 24 hours
bantime  = 24h
# Look for failures over a 10 minute window
findtime  = 10m
# Ban after 3 failures
maxretry = 3

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

echo "[4/4] Restarting and enabling Fail2ban service..."
systemctl restart fail2ban
systemctl enable fail2ban

echo "=========================================="
echo " Setup Complete!                          "
echo " Current SSH Jail Status:                 "
fail2ban-client status sshd
echo "=========================================="
