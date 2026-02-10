#!/bin/bash
set -e

SPRITE_NAME="${SPRITE_NAME:-show-scraper}"
SETUP_URL="https://dissonantp.github.io/sprite-environment/setup.sh"
LOCAL_SHOW_SCRAPER="$HOME/Desktop/Code/ShowScraper"
REMOTE_DIR="/home/sprite/ShowScraper_Standalone"

# Base provisioning (Docker, Codex, Playwright MCP, gh CLI)
curl -sL "$SETUP_URL" | bash -s -- --name "$SPRITE_NAME" --repo dissonantP/ShowScraper_Standalone

# Copy .env
echo "==> Copying .env"
sprite exec -s $SPRITE_NAME -file "$LOCAL_SHOW_SCRAPER/.env:$REMOTE_DIR/.env" true

# Copy credentials
echo "==> Copying credentials"
sprite exec -s $SPRITE_NAME mkdir -p "$REMOTE_DIR/credentials"
sprite exec -s $SPRITE_NAME -file "$LOCAL_SHOW_SCRAPER/credentials/showscraper-04e33a342c5a.json:$REMOTE_DIR/credentials/credentials.json" true

echo "==> ShowScraper sprite ready"
