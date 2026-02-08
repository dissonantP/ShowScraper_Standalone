#!/bin/bash
set -e

echo "=== ShowScraper Setup ==="
echo ""

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
  cp .env.example .env
  echo "✓ Created .env from .env.example"
else
  echo "✓ .env already exists"
fi

# Create credentials directory
mkdir -p credentials

# Handle credentials JSON (from Codespaces secret or manual)
if [ ! -z "$STORAGE_CREDENTIALS_JSON" ]; then
  echo "$STORAGE_CREDENTIALS_JSON" > credentials/showscraper.json
  chmod 600 credentials/showscraper.json
  echo "✓ Credentials written to credentials/showscraper.json"

  # Add to current shell session
  export STORAGE_CREDENTIALS="$(pwd)/credentials/showscraper.json"
  export CREDENTIALS_PATH="$(pwd)/credentials"

  echo "✓ Set STORAGE_CREDENTIALS=$(pwd)/credentials/showscraper.json"
else
  echo "⚠️  STORAGE_CREDENTIALS_JSON not set"
  echo "   Either set it as a Codespaces secret, or manually place credentials in credentials/showscraper.json"
fi

# Create logs directory
mkdir -p logs

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. docker-compose up -d"
echo "  2. docker-compose exec scraper bin/run_scraper"
echo ""
