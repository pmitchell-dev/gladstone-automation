#!/bin/bash
# ==========================================================
# HUB (PI 5) — GRAVITY SYNC INSTALLER
# ==========================================================
# Installs and configures Gravity Sync to keep Hub Pi-Hole
# in sync with the primary Webhost Pi-Hole.
#
# Sync direction: Webhost (PRIMARY) ──► Hub (SECONDARY)
# Webhost Pi-Hole:  192.168.50.217  (container: pihole)
# Hub Pi-Hole:      192.168.50.138  (container: pihole-hub)
#
# Gravity Sync will pull blocklists, custom DNS, whitelists,
# blacklists, CNAME records, and ad-list groups from the
# Webhost every hour via cron (managed by install_hub_cron.sh).
#
# Prerequisites:
#   - Pi-Hole must be running on both Hub and Webhost.
#   - SSH access from Hub to Webhost (key-based, no password).
#
# Usage: bash ~/scripts/hub/scripts/install_hub_gravity_sync.sh
# ==========================================================

set -euo pipefail

LOG_DIR="$HOME/scripts/logs"
GRAVITY_SYNC_DIR="$HOME/.config/gravity-sync"
SSH_KEY="$HOME/.ssh/gravity_sync_rsa"
WEBHOST_IP="192.168.50.217"
WEBHOST_USER="gladstone"
REMOTE_PIHOLE_DIR="/home/gladstone/pihole"
LOCAL_PIHOLE_DIR="$HOME/pihole-hub"
TOPIC="patrick_mitch_pi5_x9k2v_alerts"

mkdir -p "$LOG_DIR" "$GRAVITY_SYNC_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install_hub_gravity_sync.log"; }

# ----------------------------------------------------------
# 1. VERIFY PI-HOLE IS RUNNING ON HUB
# ----------------------------------------------------------
log "🔍 Verifying Hub Pi-Hole is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^pihole-hub$"; then
    log "❌ pihole-hub container is not running."
    log "   Run install_hub_pihole.sh first, then retry."
    exit 1
fi
log "✅ pihole-hub container confirmed running."

# ----------------------------------------------------------
# 2. INSTALL GRAVITY SYNC
# ----------------------------------------------------------
log "📦 Installing Gravity Sync..."
if command -v gravity-sync &>/dev/null; then
    log "ℹ️  Gravity Sync already installed. Skipping download."
else
    curl -sSL https://raw.githubusercontent.com/vmstan/gravity-sync/main/install.sh \
        | bash >> "$LOG_DIR/install_hub_gravity_sync.log" 2>&1
    log "✅ Gravity Sync installed."
fi

# ----------------------------------------------------------
# 3. GENERATE SSH KEY (if needed)
# ----------------------------------------------------------
log "🔑 Setting up SSH key for Gravity Sync..."
if [ ! -f "$SSH_KEY" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -C "gravity-sync@gladstone-hub" \
        >> "$LOG_DIR/install_hub_gravity_sync.log" 2>&1
    log "✅ SSH key generated at $SSH_KEY"
else
    log "ℹ️  SSH key already exists at $SSH_KEY. Skipping generation."
fi

# ----------------------------------------------------------
# 4. WRITE GRAVITY SYNC CONFIG
# ----------------------------------------------------------
log "📝 Writing Gravity Sync configuration..."

cat > "$GRAVITY_SYNC_DIR/gravity-sync.conf" <<EOF
# ==========================================================
# GRAVITY SYNC CONFIGURATION
# Hub Pi-Hole (Secondary) ← Webhost Pi-Hole (Primary)
# ==========================================================

# Remote Pi-Hole host details
REMOTE_HOST="${WEBHOST_IP}"
REMOTE_USER="${WEBHOST_USER}"

# SSH key for authentication (no-password access)
SSH_KEYFILE="${SSH_KEY}"

# Docker container names
LOCAL_DOCKER_CONTAINER="pihole-hub"
REMOTE_DOCKER_CONTAINER="pihole"

# Pi-Hole data directories
LOCAL_PIHOLE_DIRECTORY="${LOCAL_PIHOLE_DIR}/etc-pihole"
REMOTE_PIHOLE_DIRECTORY="${REMOTE_PIHOLE_DIR}/etc-pihole"

# Sync options
SYNCING_BLOCKLIST=true
SYNCING_ADLISTS=true
SYNCING_WHITELIST=true
SYNCING_BLACKLIST=true
SYNCING_CNAME=true
SYNCING_CUSTOM_DNS=true

# Logging
GRAVITY_SYNC_LOG="${LOG_DIR}/gravity_sync.log"
EOF

log "✅ Gravity Sync config written."

# ----------------------------------------------------------
# 5. DISPLAY SSH AUTHORIZATION INSTRUCTIONS
# ----------------------------------------------------------
PUB_KEY=$(cat "${SSH_KEY}.pub")

echo ""
echo "============================================================"
echo "  🔑 SSH AUTHORIZATION REQUIRED — ACTION NEEDED"
echo "============================================================"
echo ""
echo "  The SSH key lives on THIS HUB. You must push it to the Webhost."
echo ""
echo "  ▶  Run this command FROM THE HUB (you are already here):"
echo "     ssh-copy-id -i ${SSH_KEY}.pub ${WEBHOST_USER}@${WEBHOST_IP}"
echo ""
echo "  OR if you prefer to authorize manually on the Webhost,"
echo "  append this public key to the Webhost's ~/.ssh/authorized_keys:"
echo ""
echo "  ${PUB_KEY}"
echo ""
echo "  Then verify connectivity from the Hub with:"
echo "  ssh -i ${SSH_KEY} ${WEBHOST_USER}@${WEBHOST_IP} 'echo OK'"
echo "============================================================"
echo ""
echo "  Once SSH is authorized, run a manual sync to verify:"
echo "  gravity-sync pull"
echo ""
echo "  Automatic hourly sync will be managed by cron."
echo "  (Run install_hub_cron.sh to register the schedule.)"
echo "============================================================"

log "⏳ Gravity Sync install complete. Waiting for SSH authorization (manual step required)."

# ----------------------------------------------------------
# 6. TEST SSH CONNECTIVITY (NON-BLOCKING)
# ----------------------------------------------------------
log "🔌 Testing SSH connectivity to Webhost..."
if ssh -i "$SSH_KEY" -o "BatchMode=yes" -o "ConnectTimeout=5" \
       "${WEBHOST_USER}@${WEBHOST_IP}" "echo OK" &>/dev/null; then
    log "✅ SSH connectivity confirmed. Running initial sync..."
    gravity-sync pull >> "$LOG_DIR/gravity_sync.log" 2>&1 && \
        log "✅ Initial Gravity Sync pull successful." || \
        log "⚠️  Initial sync pull had errors. Check $LOG_DIR/gravity_sync.log"
else
    log "⚠️  SSH not yet authorized — initial sync skipped."
    log "   Complete the SSH authorization step above, then run: gravity-sync pull"
fi

log "🎉 Gravity Sync setup complete."
