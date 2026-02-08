#!/bin/bash
# Entrypoint script that handles environment setup and optional cron

# Load .env file if it exists (for local development)
if [ -f /app/.env ]; then
  set -a
  source /app/.env
  set +a
fi

# Handle credentials JSON from environment variable
# Format: pass STORAGE_CREDENTIALS_JSON as base64-encoded JSON
if [ ! -z "$STORAGE_CREDENTIALS_JSON" ]; then
  mkdir -p /app/credentials
  echo "$STORAGE_CREDENTIALS_JSON" > /app/credentials/showscraper.json
  chmod 600 /app/credentials/showscraper.json
  export STORAGE_CREDENTIALS=/app/credentials/showscraper.json
fi

# If CMD is "cron", run cron in foreground
# Otherwise, run whatever command was specified (or keep container alive)
if [ "$1" = "cron" ]; then
  exec cron -f
else
  # Keep container running with no foreground process
  exec "$@"
fi
