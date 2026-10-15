#!/bin/bash
# ==========================================================
# HUB (PI 5) — NEBULA SYNC INSTALLER
# ==========================================================
# Installs and configures Nebula Sync to keep the Hub Pi-Hole
# in sync with the primary Webhost Pi-Hole.
#
# Replaces Gravity Sync (archived July 2024, Pi-hole v5 only).
# Nebula Sync uses Pi-hole v6's REST API — no SSH keys needed.
#
# Sync direction: Webhost (PRIMARY) ──► Hub (SECONDARY)
# Webhost Pi-Hole:  http://192.168.50.217:8053/admin
# Hub Pi-Hole:      http://192.168.50.138:8054/admin
#
# What syncs: blocklists, adlists, whitelist, blacklist,
#             CNAME records, custom DNS, regex filters,
#             group assignments.
#
# Sync schedule: every hour (configurable via CRON env var)
#
# Prerequisites:
#   - Docker must be installed and running.
#   - Pi-Hole must be running on BOTH Hub and Webhost.
#   - ~/.gladstone_secrets must contain PIHOLE_PASSWORD.
#   - The Hub Pi-Hole replica must have app_sudo enabled
#     (this script enables it automatically via the API).
#
# Usage: bash ~/scripts/hub/scripts/install_hub_nebula_sync.sh
# ==========================================================

set -euo pipefail

LOG_DIR="$HOME/scripts/logs"
SECRETS_FILE="$HOME/.gladstone_secrets"
NEBULA_DIR="$HOME/nebula-sync"
COMPOSE_FILE="$NEBULA_DIR/docker-compose.yml"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

WEBHOST_IP="192.168.50.217"
WEBHOST_PORT="8053"
HUB_IP="192.168.50.138"
HUB_PORT="8054"

mkdir -p "$LOG_DIR" "$NEBULA_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install_hub_nebula_sync.log"; }

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

PIHOLE_PASSWORD=$(grep -m1 '^PIHOLE_PASSWORD=' "$SECRETS_FILE" | tr -d '\r' | cut -d'=' -f2- | tr -d '"')

if [ -z "${PIHOLE_PASSWORD:-}" ]; then
    log "❌ PIHOLE_PASSWORD is not set in ~/.gladstone_secrets."
    exit 1
fi

# Webhost Pi-hole password may differ (managed by Vault/Terraform on the Webhost).
# Fall back to PIHOLE_PASSWORD if PIHOLE_WEBHOST_PASSWORD is not set.
PIHOLE_WEBHOST_PASSWORD=$(grep -m1 '^PIHOLE_WEBHOST_PASSWORD=' "$SECRETS_FILE" | tr -d '\r' | cut -d'=' -f2- | tr -d '"')
if [ -z "${PIHOLE_WEBHOST_PASSWORD:-}" ]; then
    log "ℹ️  PIHOLE_WEBHOST_PASSWORD not set — using PIHOLE_PASSWORD for both instances."
    PIHOLE_WEBHOST_PASSWORD="$PIHOLE_PASSWORD"
fi

# Escape $ as $$ in passwords for docker-compose.yml (otherwise treated as shell vars)
PIHOLE_PASSWORD_ESC=$(printf '%s' "$PIHOLE_PASSWORD" | sed 's/\$/\$\$/g')
PIHOLE_WEBHOST_PASSWORD_ESC=$(printf '%s' "$PIHOLE_WEBHOST_PASSWORD" | sed 's/\$/\$\$/g')

# ----------------------------------------------------------
# 2. VERIFY BOTH PI-HOLES ARE REACHABLE
# ----------------------------------------------------------
log "🔍 Checking Webhost Pi-Hole is reachable..."
if ! curl -sf --max-time 5 "http://${WEBHOST_IP}:${WEBHOST_PORT}/admin/" &>/dev/null; then
    log "❌ Webhost Pi-Hole at http://${WEBHOST_IP}:${WEBHOST_PORT}/admin/ is not reachable."
    log "   Ensure the Webhost Pi-Hole container is running before continuing."
    exit 1
fi
log "✅ Webhost Pi-Hole is reachable."

log "🔍 Checking Hub Pi-Hole is reachable..."
if ! curl -sf --max-time 5 "http://${HUB_IP}:${HUB_PORT}/admin/" &>/dev/null; then
    log "❌ Hub Pi-Hole at http://${HUB_IP}:${HUB_PORT}/admin/ is not reachable."
    log "   Run install_hub_pihole.sh first."
    exit 1
fi
log "✅ Hub Pi-Hole is reachable."

# ----------------------------------------------------------
# 3. ENABLE app_sudo ON HUB (REPLICA) PI-HOLE
# ----------------------------------------------------------
# Nebula Sync needs write access to the replica's API.
# Pi-hole v6 requires app_sudo=true for this.
log "🔧 Enabling app_sudo on Hub Pi-Hole replica..."

# Get an API session token
HUB_TOKEN=$(curl -sf --max-time 10 \
    -X POST "http://${HUB_IP}:${HUB_PORT}/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"${PIHOLE_PASSWORD}\"}" \
    | grep -oP '"sid"\s*:\s*"\K[^"]+' || true)

if [ -z "${HUB_TOKEN:-}" ]; then
    log "⚠️  Could not authenticate with Hub Pi-Hole API to enable app_sudo."
    log "   You may need to enable it manually:"
    log "   Settings → All Settings → Webserver and API → webserver.api.app_sudo → Save"
else
    # Enable app_sudo via API
    HTTP_STATUS=$(curl -sf --max-time 10 -o /dev/null -w "%{http_code}" \
        -X PATCH "http://${HUB_IP}:${HUB_PORT}/api/config" \
        -H "Content-Type: application/json" \
        -H "X-FTL-SID: ${HUB_TOKEN}" \
        -d '{"config":{"webserver":{"api":{"app_sudo":true}}}}' || echo "000")

    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "204" ]; then
        log "✅ app_sudo enabled on Hub Pi-Hole."
    else
        log "⚠️  app_sudo API call returned HTTP $HTTP_STATUS."
        log "   Enable manually if sync fails: Settings → All Settings → webserver.api.app_sudo"
    fi
fi

# ----------------------------------------------------------
# 4. WRITE DOCKER COMPOSE & ENV FILES
# ----------------------------------------------------------
# Use an env_file approach so passwords with special characters ($, #, |)
# are never subject to shell or docker-compose variable interpolation.
ENV_FILE="$NEBULA_DIR/.env"

log "📝 Writing Nebula Sync env file to $ENV_FILE..."

# printf safely writes values without any quoting/escaping issues
# NOTE: Pi-hole v6 API is at /api NOT /admin/api — do NOT include /admin in the URL.
#       Nebula Sync appends /api internally, so just provide the base host:port.
printf 'PRIMARY=http://%s:%s|%s\n' \
    "$WEBHOST_IP" "$WEBHOST_PORT" "$PIHOLE_WEBHOST_PASSWORD" > "$ENV_FILE"
printf 'REPLICAS=http://%s:%s|%s\n' \
    "$HUB_IP" "$HUB_PORT" "$PIHOLE_PASSWORD" >> "$ENV_FILE"
printf 'FULL_SYNC=true\nRUN_GRAVITY=true\nCRON=0 * * * *\n' >> "$ENV_FILE"
chmod 600 "$ENV_FILE"
log "✅ Env file written (permissions: 600)."

log "📝 Writing Nebula Sync compose file to $COMPOSE_FILE..."

# Compose is fully static — all secrets come from the env_file above
cat > "$COMPOSE_FILE" <<'COMPOSE_EOF'
services:
  nebula-sync:
    image: ghcr.io/lovelaze/nebula-sync:latest
    container_name: nebula-sync
    restart: unless-stopped
    env_file:
      - .env
COMPOSE_EOF

log "✅ Nebula Sync compose file written."

# ----------------------------------------------------------
# 5. PULL IMAGE & START CONTAINER
# ----------------------------------------------------------
log "🐳 Pulling Nebula Sync image..."
docker compose -f "$COMPOSE_FILE" pull >> "$LOG_DIR/install_hub_nebula_sync.log" 2>&1

log "🚀 Starting Nebula Sync container..."
docker compose -f "$COMPOSE_FILE" up -d >> "$LOG_DIR/install_hub_nebula_sync.log" 2>&1

# ----------------------------------------------------------
# 6. VERIFY & TRIGGER INITIAL SYNC
# ----------------------------------------------------------
sleep 5
if docker ps --format '{{.Names}}' | grep -q "^nebula-sync$"; then
    log "✅ nebula-sync container is running."
    log "⏳ Waiting 15 seconds for initial sync to complete..."
    sleep 15

    echo ""
    echo "============================================================"
    echo "  ✅ Nebula Sync is UP"
    echo "  🔄 Syncing:  Webhost → Hub (hourly)"
    echo "  📋 Logs:     docker logs -f nebula-sync"
    echo ""
    echo "  VERIFY SYNC:"
    echo "  docker logs nebula-sync | tail -20"
    echo ""
    echo "  NEXT STEPS:"
    echo "  1. Confirm sync ran cleanly (check logs above)."
    echo "  2. Visit http://${HUB_IP}:${HUB_PORT}/admin and verify"
    echo "     blocklists match the Webhost Pi-Hole."
    echo "  3. Run Tailscale installer if not done already:"
    echo "     bash ~/scripts/hub/scripts/install_hub_tailscale.sh"
    echo "  4. Set router secondary DNS to ${HUB_IP} for LAN failover."
    echo "============================================================"

    # Show initial sync logs
    echo ""
    log "📋 Initial sync log output:"
    docker logs nebula-sync 2>&1 | tee -a "$LOG_DIR/install_hub_nebula_sync.log" || true
else
    log "❌ nebula-sync container failed to start. Check logs:"
    log "   docker logs nebula-sync"
    log "   cat $LOG_DIR/install_hub_nebula_sync.log"
    curl -s -H "Priority: 4" \
         -d "[$HOSTNAME] ❌ Nebula Sync install FAILED. Check logs." \
         "https://ntfy.sh/$TOPIC" || true
    exit 1
fi

log "🎉 Nebula Sync setup complete."
