#!/bin/bash
# ==========================================================
# HUB (PI 5) — PI-HOLE INSTALLER (DOCKER)
# ==========================================================
# Runs Pi-Hole in a Docker container on the Hub.
# Always-on secondary DNS server — run alongside the primary
# Pi-Hole on the Webhost (192.168.50.217).
#
# Web Admin UI: http://192.168.50.138:8054
# DNS:          Port 53 (TCP/UDP) on 192.168.50.138
#
# Prerequisites:
#   - Docker must be installed and running.
#   - ~/.gladstone_secrets must contain PIHOLE_PASSWORD.
#
# Usage: bash ~/scripts/hub/scripts/install_hub_pihole.sh
# ==========================================================

set -euo pipefail

LOG_DIR="$HOME/scripts/logs"
SECRETS_FILE="$HOME/.gladstone_secrets"
PIHOLE_DIR="$HOME/pihole-hub"
COMPOSE_FILE="$PIHOLE_DIR/docker-compose.yml"
ETC_PIHOLE="$PIHOLE_DIR/etc-pihole"
ETC_DNSMASQ="$PIHOLE_DIR/etc-dnsmasq.d"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"
HUB_LAN_IP="192.168.50.138"
WEB_PORT="8054"

mkdir -p "$LOG_DIR" "$ETC_PIHOLE" "$ETC_DNSMASQ"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install_hub_pihole.log"; }

# ----------------------------------------------------------
# 1. VALIDATE PREREQUISITES
# ----------------------------------------------------------
log "🔍 Validating prerequisites..."

if ! command -v docker &>/dev/null; then
    log "❌ Docker is not installed or not in PATH. Aborting."
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    log "❌ ~/.gladstone_secrets not found."
    log "   Create it and add: PIHOLE_PASSWORD=\"yourpassword\""
    exit 1
fi

# Parse secrets safely (immune to CRLF / Windows line endings)
PIHOLE_PASSWORD=$(grep -m1 '^PIHOLE_PASSWORD=' "$SECRETS_FILE" | tr -d '\r' | cut -d'=' -f2- | tr -d '"')

if [ -z "${PIHOLE_PASSWORD:-}" ]; then
    log "❌ PIHOLE_PASSWORD is not set in ~/.gladstone_secrets."
    log "   Add it: PIHOLE_PASSWORD=\"yourpassword\""
    exit 1
fi

# ----------------------------------------------------------
# 2. CHECK PORT 53 AVAILABILITY
# ----------------------------------------------------------
log "🔍 Checking if port 53 is free..."
if sudo ss -tlunp 2>/dev/null | grep -q ':53 ' || sudo lsof -i :53 -sTCP:LISTEN 2>/dev/null | grep -qv docker; then
    log "⚠️  Port 53 may be in use by systemd-resolved. Disabling stub listener..."
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo bash -c 'cat > /etc/systemd/resolved.conf.d/nopiggyback.conf <<EOF
[Resolve]
DNSStubListener=no
EOF'
    sudo systemctl restart systemd-resolved
    log "✅ systemd-resolved stub listener disabled."
fi

# ----------------------------------------------------------
# 3. WRITE DOCKER COMPOSE FILE
# ----------------------------------------------------------
log "📝 Writing Pi-Hole compose file to $COMPOSE_FILE..."
mkdir -p "$PIHOLE_DIR"

cat > "$COMPOSE_FILE" <<EOF
services:
  pihole-hub:
    image: pihole/pihole:latest
    container_name: pihole-hub
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "${WEB_PORT}:80/tcp"
    environment:
      TZ: "America/Chicago"
      FTLCONF_webserver_api_password: "${PIHOLE_PASSWORD}"
      FTLCONF_LOCAL_IPV4: "${HUB_LAN_IP}"
      FTLCONF_dns_listeningMode: "ALL"
      PIHOLE_DNS_: "1.1.1.1;1.0.0.1"
    volumes:
      - ${ETC_PIHOLE}:/etc/pihole
      - ${ETC_DNSMASQ}:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
EOF

log "✅ Compose file written."

# ----------------------------------------------------------
# 4. PULL IMAGE & START CONTAINER
# ----------------------------------------------------------
log "🐳 Pulling Pi-Hole image..."
docker compose -f "$COMPOSE_FILE" pull >> "$LOG_DIR/install_hub_pihole.log" 2>&1

log "🚀 Starting Pi-Hole container..."
docker compose -f "$COMPOSE_FILE" up -d >> "$LOG_DIR/install_hub_pihole.log" 2>&1

# ----------------------------------------------------------
# 5. VERIFY
# ----------------------------------------------------------
sleep 8
if docker ps --format '{{.Names}}' | grep -q "^pihole-hub$"; then
    log "✅ pihole-hub container is running."
    echo ""
    echo "============================================================"
    echo "  ✅ Pi-Hole Hub Node is UP"
    echo "  🌐 Web Admin:  http://${HUB_LAN_IP}:${WEB_PORT}/admin"
    echo "  📡 DNS Port:   ${HUB_LAN_IP}:53"
    echo ""
    echo "  NEXT STEPS:"
    echo "  1. Verify Pi-Hole is working:"
    echo "     dig @${HUB_LAN_IP} google.com"
    echo "  2. Run Gravity Sync setup to mirror blocklists from Webhost:"
    echo "     bash ~/scripts/hub/scripts/install_hub_gravity_sync.sh"
    echo "  3. Add this Hub's Tailscale IP as a DNS server at:"
    echo "     https://login.tailscale.com/admin/dns"
    echo "  4. Set your router's secondary DNS to ${HUB_LAN_IP} for"
    echo "     LAN-wide fallback coverage."
    echo "============================================================"
else
    log "❌ pihole-hub container failed to start. Check logs:"
    log "   docker logs pihole-hub"
    log "   cat $LOG_DIR/install_hub_pihole.log"
    curl -s -H "Priority: 4" \
         -d "[$HOSTNAME] ❌ Pi-Hole Hub install FAILED. Check logs." \
         "https://ntfy.sh/$TOPIC" || true
    exit 1
fi

log "🎉 Pi-Hole Hub install complete."
