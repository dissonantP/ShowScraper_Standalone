#!/bin/bash
set -e

# Post-create script for Codespaces
# This sets up environment variables from secrets

# If running in Codespaces, GitHub secrets are already injected as env vars
# If running locally, load from .env file

if [ ! -f /app/.env ]; then
  # Create .env from example if it doesn't exist
  cp /app/.env.example /app/.env
  echo "Created .env from .env.example"
  
  # If we're in Codespaces, the secrets should already be set as env vars
  # If running locally, user needs to manually edit .env
  if [ -z "$CODESPACES" ]; then
    echo "⚠️  .env created from .env.example"
    echo "Please update it with your configuration values and credentials JSON path"
  fi
fi

# Handle credentials JSON
# In Codespaces: STORAGE_CREDENTIALS_JSON env var contains the JSON
# Locally: STORAGE_CREDENTIALS env var points to file path
if [ ! -z "$STORAGE_CREDENTIALS_JSON" ]; then
  mkdir -p /app/credentials
  echo "$STORAGE_CREDENTIALS_JSON" > /app/credentials/showscraper.json
  chmod 600 /app/credentials/showscraper.json
  export STORAGE_CREDENTIALS=/app/credentials/showscraper.json
  echo "✓ Credentials JSON written from environment variable"
fi

echo "✓ Setup complete"
