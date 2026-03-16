#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Deploying from $REPO_DIR"

cd "$REPO_DIR"
docker compose pull --quiet
docker compose up -d --remove-orphans

echo ""
echo "Deploy complete."
