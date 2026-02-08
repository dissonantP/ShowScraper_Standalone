# Development Container Setup

This directory contains configuration for GitHub Codespaces and local development containers.

## Architecture

**Simplified Docker-in-Docker approach:**
- Devcontainer uses standard Ubuntu base image with Docker-in-Docker feature
- You run `docker-compose` inside the devcontainer to start the scraper
- No duplication of Dockerfiles - single production Dockerfile in root

## Key Files

- **devcontainer.json**: VS Code devcontainer configuration with Docker-in-Docker
- **post-create.sh**: Sets up credentials and environment on first launch
- **verify-setup.sh**: Diagnostic script to check your setup

## How It Works

1. **Devcontainer boots** with Ubuntu + Docker + Ruby + Git
2. **Post-create script runs** and:
   - Creates `.env` from `.env.example` if needed
   - Writes credentials from `STORAGE_CREDENTIALS_JSON` secret
   - Adds `STORAGE_CREDENTIALS` to your shell environment
3. **You run docker-compose** inside the devcontainer:
   ```bash
   docker-compose up -d
   docker-compose exec scraper bin/run_scraper
   ```

## Environment Variables

Configure these as **Codespaces secrets** (repo or user level):
- `STORAGE_CREDENTIALS_JSON` - Full JSON content of GCS credentials
- `STORAGE_PROJECT` - GCP project ID
- `GCS_BUCKET` - Production GCS bucket name
- `GCS_TEST_BUCKET` - Test GCS bucket name (optional)
- `NO_GCS` - Set to "true" to disable GCS (optional)

These are automatically passed through to `docker-compose` via the host environment.

## Development Workflow

### First Time Setup
1. Configure Codespaces secrets (see above)
2. Open repository in Codespaces
3. Wait for devcontainer to build
4. Verify setup: `bash .devcontainer/verify-setup.sh`

### Daily Usage
```bash
# Start the scraper container
docker-compose up -d

# Run the scraper
docker-compose exec scraper bin/run_scraper

# View logs
docker-compose logs -f scraper

# Stop
docker-compose down
```

### Making Code Changes
- Edit files directly in the workspace
- Rebuild the image: `docker-compose build`
- Restart: `docker-compose up -d`

## Production vs Development

### Production (root Dockerfile)
- Minimal `ruby:3.3-slim` image
- Published to `ghcr.io/dissonantp/showscraper_standalone:latest`
- Auto-built by GitHub Actions on push to main/master

### Development (this setup)
- Standard Ubuntu devcontainer with Docker
- You build/run the production image locally via docker-compose
- Full dev tools available (git, editors, etc.)

## Troubleshooting

Run the diagnostic script:
```bash
bash .devcontainer/verify-setup.sh
```

### Common Issues

**Credentials not found**
- Check that `STORAGE_CREDENTIALS_JSON` is set as a Codespaces secret
- Rebuild the Codespace (Full Rebuild)

**Docker not available**
- This shouldn't happen - Docker-in-Docker is configured
- Try: `sudo service docker start`

**Environment variables not set in docker-compose**
- They're passed through from the host (devcontainer shell)
- Verify they're set in your shell: `env | grep STORAGE`
