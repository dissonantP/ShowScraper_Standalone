#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
$SCRIPT_DIR/show_scraper_setup.sh
$SCRIPT_DIR/codex_setup.sh