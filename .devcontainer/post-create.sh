#!/bin/bash
set -e

echo "=== Post-Create Setup ==="
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

# Handle credentials JSON for Codespaces
# GitHub Codespaces secrets are automatically available as environment variables
if [ ! -z "$STORAGE_CREDENTIALS_JSON" ]; then
  echo "$STORAGE_CREDENTIALS_JSON" > credentials/showscraper.json
  chmod 600 credentials/showscraper.json
  echo "✓ Credentials written to credentials/showscraper.json from STORAGE_CREDENTIALS_JSON"

  # Export for current shell (and add to .bashrc for future shells)
  export STORAGE_CREDENTIALS="$(pwd)/credentials/showscraper.json"
  if ! grep -q "STORAGE_CREDENTIALS" ~/.bashrc; then
    echo "export STORAGE_CREDENTIALS=\"\$(pwd)/credentials/showscraper.json\"" >> ~/.bashrc
    echo "✓ Added STORAGE_CREDENTIALS to ~/.bashrc"
  fi
else
  echo "⚠️  STORAGE_CREDENTIALS_JSON not set - you'll need to manually add credentials"
fi

# Create logs directory
mkdir -p logs

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To run the scraper:"
echo "  1. docker-compose up -d"
echo "  2. docker-compose exec scraper bin/run_scraper"
echo ""
echo "To verify setup:"
echo "  bash .devcontainer/verify-setup.sh"
echo ""
