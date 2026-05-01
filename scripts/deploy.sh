#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MYNKIE_IMAGE="${MYNKIE_IMAGE:-ghcr.io/therealminhduc/mynkie:latest}"

echo "==> Deploying from $REPO_DIR"

cd "$REPO_DIR"

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

SITE_DIR="${MYNKIE_SITE_DIR:-./data/mynkie-site}"
RELEASES_DIR="$SITE_DIR/releases"
RELEASE_ID="$(date -u +%Y%m%d%H%M%S)"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"
CURRENT_LINK="$SITE_DIR/current"
NEXT_LINK="$SITE_DIR/.next-current"

echo "==> Pulling $MYNKIE_IMAGE"
docker pull --quiet "$MYNKIE_IMAGE"

echo "==> Extracting mynkie static files to $RELEASE_DIR"
mkdir -p "$RELEASE_DIR"
container_id="$(docker create "$MYNKIE_IMAGE")"
cleanup() {
    docker rm -f "$container_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker cp "$container_id:/usr/share/nginx/html/." "$RELEASE_DIR"
cleanup
trap - EXIT

echo "==> Publishing mynkie release $RELEASE_ID"
rm -f "$NEXT_LINK"
ln -s "releases/$RELEASE_ID" "$NEXT_LINK"
if ! mv -Tf "$NEXT_LINK" "$CURRENT_LINK" 2>/dev/null; then
    if ! mv -fh "$NEXT_LINK" "$CURRENT_LINK" 2>/dev/null; then
        rm -f "$CURRENT_LINK"
        mv "$NEXT_LINK" "$CURRENT_LINK"
    fi
fi

docker compose up -d --remove-orphans

echo "==> Validating and reloading nginx"
docker compose exec -T nginx nginx -t
if ! docker compose kill -s HUP nginx >/dev/null 2>&1; then
    docker compose restart nginx
fi

echo "==> Restarting cloudflared to reload tunnel ingress"
docker compose restart cloudflared

echo ""
echo "Deploy complete."
