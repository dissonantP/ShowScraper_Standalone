#!/bin/bash
# Wrapper script to ensure environment is loaded for cron jobs

# Load environment variables from Docker
export PATH=/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Change to app directory
cd /app

# Run the scraper with full output
echo "=== Cron run started at $(date) ===" >> /app/logs/cron.log
bin/run_scraper >> /app/logs/cron.log 2>&1
EXIT_CODE=$?
echo "=== Cron run finished at $(date) with exit code $EXIT_CODE ===" >> /app/logs/cron.log
echo "" >> /app/logs/cron.log
