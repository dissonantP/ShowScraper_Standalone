#!/bin/bash
set -e

echo "=== ShowScraper Codespaces Setup ==="
echo ""

# Create credentials directory
mkdir -p credentials

# Write credentials from env var
if [ ! -z "$STORAGE_CREDENTIALS_JSON" ]; then
  echo "$STORAGE_CREDENTIALS_JSON" > credentials/showscraper.json
  chmod 600 credentials/showscraper.json
  echo "✓ Credentials written to credentials/showscraper.json"
else
  echo "⚠️  STORAGE_CREDENTIALS_JSON not set"
  echo "   Set this as a Codespaces secret to enable GCS"
fi

# Create logs directory
mkdir -p logs

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Start with cron (default):"
echo "  docker-compose up -d"
echo ""
echo "Or run once without cron:"
echo "  docker-compose run --rm scraper bin/run_scraper"
echo ""
