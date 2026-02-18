#!/bin/bash
set -e

SPRITE_NAME="${SPRITE_NAME:-show-scraper}"
DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/home/sprite/ShowScraper_Standalone"

sprite exec -s $SPRITE_NAME git clone git@github.com:dissonantP/ShowScraper_Standalone.git
# Copy .env
echo "==> Copying .env"
sprite exec -s $SPRITE_NAME -file "$DIR/.env:$REMOTE_DIR/.env" true

# Copy credentials
echo "==> Copying credentials"
sprite exec -s $SPRITE_NAME mkdir -p "$REMOTE_DIR/credentials"
sprite exec -s $SPRITE_NAME -file "$DIR/credentials/credentials.json:$REMOTE_DIR/credentials/credentials.json" true

# Run setup script (handles Firefox and geckodriver download)
echo "==> Running setup script"
sprite exec -s $SPRITE_NAME -dir "$REMOTE_DIR" ruby setup.rb

echo "==> ShowScraper sprite ready"
