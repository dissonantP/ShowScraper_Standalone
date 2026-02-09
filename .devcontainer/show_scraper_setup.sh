#!/bin/bash
set -e

mkdir -p credentials
mkdir -p logs

echo "$STORAGE_CREDENTIALS_JSON" > credentials/showscraper.json
chmod 600 credentials/showscraper.json
