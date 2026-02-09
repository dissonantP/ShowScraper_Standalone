#!/bin/bash
set -e

npm i -g @openai/codex
mkdir -p ~/.codex

# Make sure to set this value on Github Codespaces config
echo $CODEX_AUTH > ~/.codex/auth.json