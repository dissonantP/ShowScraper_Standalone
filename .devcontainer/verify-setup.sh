#!/bin/bash
# Quick diagnostic script to verify devcontainer setup

echo "=== Codespace Environment Check ==="
echo ""

echo "✓ Checking if CODESPACES is set:"
echo "  CODESPACES=$CODESPACES"
echo ""

echo "✓ Checking if STORAGE_CREDENTIALS is set:"
if [ -z "$STORAGE_CREDENTIALS" ]; then
  echo "  ❌ STORAGE_CREDENTIALS is NOT set"
else
  echo "  ✓ STORAGE_CREDENTIALS=$STORAGE_CREDENTIALS"
fi
echo ""

echo "✓ Checking if credentials file exists:"
if [ -f "/app/credentials/showscraper.json" ]; then
  echo "  ✓ /app/credentials/showscraper.json exists"
  echo "  Size: $(stat -f%z /app/credentials/showscraper.json 2>/dev/null || stat -c%s /app/credentials/showscraper.json) bytes"
else
  echo "  ❌ /app/credentials/showscraper.json NOT found"
fi
echo ""

echo "✓ Checking if .env exists:"
if [ -f "/app/.env" ]; then
  echo "  ✓ /app/.env exists"
else
  echo "  ❌ /app/.env NOT found (this is OK if using env vars)"
fi
echo ""

echo "✓ Checking Git availability:"
if command -v git &> /dev/null; then
  echo "  ✓ git is available: $(git --version)"
else
  echo "  ❌ git is NOT available"
fi
echo ""

echo "✓ Ruby version:"
ruby --version
echo ""

echo "=== Summary ==="
if [ ! -z "$STORAGE_CREDENTIALS" ] && [ -f "$STORAGE_CREDENTIALS" ]; then
  echo "✅ Setup looks good! You should be able to run the scraper."
else
  echo "⚠️  Issues detected. Check the output above."
  echo ""
  echo "To fix:"
  echo "1. Make sure you've set STORAGE_CREDENTIALS_JSON as a Codespace secret"
  echo "2. Rebuild the Codespace (Full Rebuild)"
  echo "3. Run this script again: bash .devcontainer/verify-setup.sh"
fi
