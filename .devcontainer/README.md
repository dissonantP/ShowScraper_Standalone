# Development Container Setup

This directory contains configuration for GitHub Codespaces and local development containers.

## Key Files

- **Dockerfile**: Development-specific Docker image with full dev tools (git, vim, etc.)
- **docker-compose.dev.yml**: Development Docker Compose configuration with workspace mounted
- **devcontainer.json**: VS Code devcontainer configuration
- **post-create.sh**: Post-creation setup script for credentials

## Development vs Production

### Development (this setup)
- Based on full `ruby:3.3` image (not slim)
- Includes git, vim, curl, and other dev tools
- Mounts workspace as volume (changes reflected immediately)
- Builds from local Dockerfile

### Production (root Dockerfile)
- Based on minimal `ruby:3.3-slim` image
- Only includes runtime dependencies
- Copies code into image (immutable)
- Published to GitHub Container Registry via Actions
- Used by docker-compose.yml in root

## GitHub Actions Workflow

The `.github/workflows/docker-build.yml` automatically builds and publishes the **production** image on:
- Push to `main` or `master` branches
- Manual workflow dispatch

The production image is tagged as `ghcr.io/dissonantp/showscraper_standalone:latest`

## Development Workflow

1. **In Codespaces**: Open repo → Codespaces builds dev container automatically
2. **Locally**: Open in VS Code with Dev Containers extension

Changes to code are immediately reflected (no rebuild needed) because the workspace is mounted.

## Updating Dependencies

If you modify `Gemfile`:
1. Run `bundle install` in the container
2. Rebuild container: `Cmd/Ctrl + Shift + P` → "Rebuild Container"

## Secrets for Codespaces

Configure these as repository secrets:
- `STORAGE_CREDENTIALS_JSON`: GCS credentials JSON content
- `STORAGE_PROJECT`: GCP project ID
- `GCS_BUCKET`: GCS bucket name

The post-create script automatically writes the credentials file from the env var.
