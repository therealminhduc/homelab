#!/usr/bin/env bash
set -euo pipefail

NGINX_SERVERS_DIR="/opt/homebrew/etc/nginx/servers"
CLOUDFLARED_CONFIG="$HOME/.cloudflared/config.yml"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Deploying from $REPO_DIR"

# --- Nginx ---
echo "==> Syncing nginx configs..."
mkdir -p "$NGINX_SERVERS_DIR"
cp "$REPO_DIR/nginx/servers/"*.conf "$NGINX_SERVERS_DIR/"
nginx -t
nginx -s reload
echo "    nginx reloaded OK"

# --- Cloudflared ---
echo "==> Syncing cloudflared config..."
cp "$REPO_DIR/cloudflared/config.yml" "$CLOUDFLARED_CONFIG"
sudo launchctl stop com.cloudflare.cloudflared  2>/dev/null || true
sudo launchctl start com.cloudflare.cloudflared
echo "    cloudflared restarted OK"

# --- Docker stack ---
echo "==> Updating Docker stack..."
cd "$REPO_DIR"
docker compose pull --quiet
docker compose up -d --remove-orphans
echo "    Docker stack up OK"

echo ""
echo "Deploy complete."