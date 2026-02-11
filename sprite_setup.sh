#!/bin/bash
set -e

SPRITE_NAME="${SPRITE_NAME:-show-scraper}"
SETUP_URL="https://dissonantp.github.io/sprite-environment/setup.sh"
DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/home/sprite/ShowScraper_Standalone"

# Base provisioning (Codex, Playwright MCP, gh CLI)
SETUP_TMP=$(mktemp)
curl -sL "$SETUP_URL" -o "$SETUP_TMP"
bash "$SETUP_TMP" --name "$SPRITE_NAME" --repo dissonantP/ShowScraper_Standalone
rm -f "$SETUP_TMP"

# Copy .env
echo "==> Copying .env"
sprite exec -s $SPRITE_NAME -file "$DIR/.env:$REMOTE_DIR/.env" true

# Copy credentials
echo "==> Copying credentials"
sprite exec -s $SPRITE_NAME mkdir -p "$REMOTE_DIR/credentials"
sprite exec -s $SPRITE_NAME -file "$DIR/credentials/credentials.json:$REMOTE_DIR/credentials/credentials.json" true

# Run setup script (handles Firefox and geckodriver download)
echo "==> Running setup script"
sprite exec -s $SPRITE_NAME -cwd "$REMOTE_DIR" ruby setup.rb

echo "==> ShowScraper sprite ready"
