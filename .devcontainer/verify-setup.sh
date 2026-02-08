#!/bin/bash
# Diagnostic script to verify devcontainer setup

echo "=== Codespace Environment Check ==="
echo ""

echo "✓ Checking if running in Codespaces:"
echo "  CODESPACES=${CODESPACES:-not set}"
echo ""

echo "✓ Checking Docker availability:"
if command -v docker &> /dev/null; then
  echo "  ✓ docker is available: $(docker --version)"
  echo "  ✓ docker-compose is available: $(docker-compose --version 2>/dev/null || echo 'not found')"
else
  echo "  ❌ docker is NOT available"
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
if command -v ruby &> /dev/null; then
  echo "  ✓ $(ruby --version)"
else
  echo "  ❌ ruby is NOT available"
fi
echo ""

echo "✓ Checking environment variables:"
echo "  STORAGE_PROJECT=${STORAGE_PROJECT:-not set}"
echo "  GCS_BUCKET=${GCS_BUCKET:-not set}"
echo "  NO_GCS=${NO_GCS:-not set}"
echo ""

echo "✓ Checking credentials:"
if [ -f "credentials/showscraper.json" ]; then
  echo "  ✓ credentials/showscraper.json exists"
  SIZE=$(stat -c%s credentials/showscraper.json 2>/dev/null || stat -f%z credentials/showscraper.json 2>/dev/null)
  echo "  Size: ${SIZE} bytes"
else
  echo "  ❌ credentials/showscraper.json NOT found"
fi

if [ ! -z "$STORAGE_CREDENTIALS" ]; then
  echo "  ✓ STORAGE_CREDENTIALS=$STORAGE_CREDENTIALS"
else
  echo "  ⚠️  STORAGE_CREDENTIALS not set (will be set when you source ~/.bashrc)"
fi
echo ""

echo "✓ Checking required files:"
for file in Gemfile docker-compose.yml sources.json; do
  if [ -f "$file" ]; then
    echo "  ✓ $file exists"
  else
    echo "  ❌ $file NOT found"
  fi
done
echo ""

echo "=== Summary ==="
if command -v docker &> /dev/null && [ -f "docker-compose.yml" ]; then
  echo "✅ Setup looks good! You can run:"
  echo "   docker-compose up -d"
  echo ""
  if [ -f "credentials/showscraper.json" ]; then
    echo "   Credentials are configured."
  else
    echo "   ⚠️  Don't forget to configure credentials if using GCS."
  fi
else
  echo "⚠️  Issues detected. Check the output above."
fi
