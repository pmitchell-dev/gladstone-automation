#!/bin/bash
# ==========================================================
# HUB (PI 5) — TAILSCALE INSTALLER (DOCKER)
# ==========================================================
# Runs Tailscale in a Docker container on the Hub.
# Registers a new node named "gladstone-hub" on your Tailscale
# network. Enables subnet routing (192.168.50.0/24) and
# advertises as an exit node.
#
# Prerequisites:
#   - Docker must be installed and running.
#   - ~/.gladstone_secrets must contain TS_AUTHKEY.
#
# Usage: bash ~/scripts/hub/scripts/install_hub_tailscale.sh
# ==========================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/scripts/logs"
SECRETS_FILE="$HOME/.gladstone_secrets"
STATE_DIR="$HOME/tailscale-hub/state"
COMPOSE_DIR="$HOME/tailscale-hub"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install_hub_tailscale.log"; }

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
    log "   Create it and add: TS_AUTHKEY=\"tskey-auth-xxxxxxxxx\""
    exit 1
fi

# Parse secrets safely (immune to CRLF / Windows line endings)
TS_AUTHKEY=$(grep -m1 '^TS_AUTHKEY=' "$SECRETS_FILE" | tr -d '\r' | cut -d'=' -f2- | tr -d '"')

if [ -z "${TS_AUTHKEY:-}" ]; then
    log "❌ TS_AUTHKEY is not set in ~/.gladstone_secrets."
    log "   Generate one at: https://login.tailscale.com/admin/settings/keys"
    log "   Then add: TS_AUTHKEY=\"tskey-auth-xxxxxxxxx\""
    exit 1
fi

# ----------------------------------------------------------
# 2. ENABLE IP FORWARDING (required for subnet routing)
# ----------------------------------------------------------
log "🔧 Enabling IP forwarding for subnet routing..."
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p /etc/sysctl.conf >> "$LOG_DIR/install_hub_tailscale.log" 2>&1 || true
log "✅ IP forwarding enabled."

# ----------------------------------------------------------
# 3. WRITE DOCKER COMPOSE FILE
# ----------------------------------------------------------
log "📝 Writing Tailscale compose file to $COMPOSE_FILE..."
mkdir -p "$COMPOSE_DIR"

cat > "$COMPOSE_FILE" <<EOF
services:
  tailscale-hub:
    image: tailscale/tailscale:latest
    container_name: tailscale-hub
    hostname: gladstone-hub
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ${STATE_DIR}:/var/lib/tailscale
    environment:
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=false
      - TS_AUTHKEY=${TS_AUTHKEY}
      # --reset: clears previously saved flags on restart, prevents boot-loop on flag changes
      # --advertise-routes: Hub acts as subnet router for 192.168.50.0/24
      # --accept-routes OMITTED: Hub is physically on 192.168.50.0/24 already.
      #   Accepting the Webhost's identical subnet route causes a routing conflict
      #   that breaks LAN SSH on the Hub.
      - TS_EXTRA_ARGS=--reset --hostname=gladstone-hub --advertise-routes=192.168.50.0/24
    restart: unless-stopped
EOF

log "✅ Compose file written."

# ----------------------------------------------------------
# 4. PULL IMAGE & START CONTAINER
# ----------------------------------------------------------
log "🐳 Pulling Tailscale image..."
docker compose -f "$COMPOSE_FILE" pull >> "$LOG_DIR/install_hub_tailscale.log" 2>&1

log "🚀 Starting Tailscale container..."
docker compose -f "$COMPOSE_FILE" up -d >> "$LOG_DIR/install_hub_tailscale.log" 2>&1

# ----------------------------------------------------------
# 5. VERIFY
# ----------------------------------------------------------
sleep 5
if docker ps --format '{{.Names}}' | grep -q "^tailscale-hub$"; then
    log "✅ tailscale-hub container is running."

    # Get the Tailscale IP for display
    TS_IP=$(docker exec tailscale-hub tailscale ip -4 2>/dev/null || echo "pending...")
    log "🌐 Tailscale IP: $TS_IP"
    echo ""
    echo "============================================================"
    echo "  ✅ Tailscale Hub Node is UP"
    echo "  📡 Node name:    gladstone-hub"
    echo "  🌐 Tailscale IP: $TS_IP"
    echo ""
    echo "  NEXT STEPS:"
    echo "  1. Verify the node appears in your Tailscale admin console:"
    echo "     https://login.tailscale.com/admin/machines"
    echo "  2. Approve subnet routes (192.168.50.0/24) in the admin console."
    echo "  3. Once Pi-Hole is running on this Hub, add this node's"
    echo "     Tailscale IP as a DNS server in:"
    echo "     https://login.tailscale.com/admin/dns"
    echo "============================================================"
else
    log "❌ tailscale-hub container failed to start. Check logs:"
    log "   docker logs tailscale-hub"
    log "   cat $LOG_DIR/install_hub_tailscale.log"
    curl -s -H "Priority: 4" \
         -d "[$HOSTNAME] ❌ Tailscale Hub install FAILED. Check logs." \
         "https://ntfy.sh/$TOPIC" || true
    exit 1
fi

log "🎉 Tailscale Hub install complete."
