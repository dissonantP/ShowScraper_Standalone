# ShowScraper - Docker Version

Dockerized version of the ShowScraper offline scraping process with headless Firefox browser support.

## Overview

This Docker container includes:
- Ruby 3.3.0
- Firefox ESR (headless browser)
- Geckodriver for Selenium WebDriver
- All required Ruby gems
- Event scraping logic for multiple venues

## Prerequisites

- Docker (20.10+)
- Docker Compose (optional, but recommended)
- GCS credentials file (optional, if using Google Cloud Storage)

## Quick Start

### Using Docker Compose (Recommended)

1. **Create environment file** (optional):
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Create credentials directory** (if using GCS):
   ```bash
   mkdir -p credentials
   # Place your GCS credentials JSON file in this directory
   ```

3. **Create logs directory**:
   ```bash
   mkdir -p logs
   ```

4. **Build and run**:
   ```bash
   docker-compose build
   docker-compose up
   ```

### Using Docker CLI

1. **Build the image**:
   ```bash
   docker build -t showscraper .
   ```

2. **Run the container**:
   ```bash
   docker run --rm \
     -v $(pwd)/credentials:/app/credentials:ro \
     -v $(pwd)/logs:/app/logs \
     showscraper
   ```

### Using Sprites

Provision a [Sprite](https://sprites.dev) dev environment with all tools pre-installed:

```bash
bash sprite_setup.sh
```

This runs base provisioning (Docker, Codex, Playwright MCP, gh CLI), clones the repo, and copies `.env` and GCS credentials.

## Configuration

### Environment Variables

Configure the scraper behavior using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `HEADLESS` | `true` | Run browser in headless mode |
| `NO_DB` | `true` | Skip database connection |
| `NO_GCS` | `false` | Skip Google Cloud Storage connection |
| `PRINT_EVENTS` | `true` | Print events as they are scraped |
| `PRINT_FULL_DETAIL` | `false` | Print full JSON or condensed output |
| `RESCUE_SCRAPING_ERRORS` | `true` | Continue on errors |
| `LOG_GCS_PATH` | `scraper.log` | GCS object path for condensed scraper logs |
| `LOG_GCS_PATH` cache behavior | n/a | Log uploads force `Cache-Control: no-store, max-age=0, must-revalidate` |
| `LOG_RETENTION_DAYS` | `2` | Keep only this many trailing days in GCS logs |
| `LOG_MAX_LINES` | `200` | Hard cap on retained GCS log lines |
| `LOG_PATH` | `/app/logs/scraper.log` | Local file fallback path if GCS logging is disabled |

### Command Line Options

Override the default behavior with command-line options:

```bash
# Limit number of events
docker-compose run --rm scraper bin/run_scraper --limit 50

# Scrape specific sources
docker-compose run --rm scraper bin/run_scraper --sources DnaLounge,Fillmore

# Run in non-headless mode (requires X11 forwarding)
docker-compose run --rm scraper bin/run_scraper --headless false

# Skip persisting results
docker-compose run --rm scraper bin/run_scraper --skip-persist

# Enable debugger
docker-compose run --rm scraper bin/run_scraper --debugger
```

## Volume Mounts

### Credentials (Read-only)
Mount your GCS credentials file:
```yaml
volumes:
  - ./credentials:/app/credentials:ro
```

### Logs (Read-write)
Persist scraper logs:
```yaml
volumes:
  - ./logs:/app/logs
```

### Sources (Optional)
Override sources.json dynamically:
```yaml
volumes:
  - ./sources.json:/app/sources.json:ro
```

## Google Cloud Storage Setup

If using GCS to store scraped data:

### Option 1: File-based credentials (Local Development)

1. Place your GCS credentials JSON file in `credentials/` directory
2. Set environment variables in `docker-compose.yml` or `.env`:
   ```bash
   NO_GCS=false
   STORAGE_PROJECT=your-project-id
   GCS_BUCKET=your-bucket-name
   GCS_TEST_BUCKET=your-test-bucket-name
   ```

The container will automatically detect the credentials file in the mounted volume.

## Running Without GCS

To run without Google Cloud Storage:

```bash
docker-compose run --rm -e NO_GCS=true scraper
```

## Scheduled Runs

### Using Docker Cron

The container runs with `sleep infinity` by default (no cron). To enable cron scheduling inside the container:

```bash
# Run with cron enabled
docker-compose run --rm scraper cron
```

Or override in `docker-compose.yml`:
```yaml
command: cron
```

### Using Host Cron

Add to your system crontab:
```bash
# Run scraper daily at 2 AM
0 2 * * * cd /path/to/ShowScraper && docker-compose run --rm scraper bash -c "bundle exec bin/run_scraper"
```

### Using Docker Compose in Cron

```bash
# Run scraper daily at 2 AM
0 2 * * * cd /path/to/ShowScraper && docker-compose run --rm scraper bash -c "bundle exec bin/run_scraper"
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: showscraper
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scraper
            image: showscraper:latest
            env:
            - name: NO_GCS
              value: "false"
            volumeMounts:
            - name: credentials
              mountPath: /app/credentials
              readOnly: true
          volumes:
          - name: credentials
            secret:
              secretName: gcs-credentials
          restartPolicy: OnFailure
```

## Troubleshooting

### Browser Issues

If Firefox fails to start:
- Ensure `--shm-size=2g` is set for Docker (prevents shared memory issues)
- Add to docker-compose.yml:
  ```yaml
  shm_size: 2gb
  ```

### Memory Issues

Increase memory limits in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      memory: 4G
```

### Permission Issues

Ensure volumes have correct permissions:
```bash
chmod -R 755 credentials/
chmod -R 755 logs/
```

### Viewing Logs

```bash
# Using docker-compose
docker-compose logs -f

# Using Docker CLI
docker logs -f showscraper

# View local fallback file logs
tail -f logs/scraper.log

# View GCS log object (requires gsutil)
gsutil cat gs://$GCS_BUCKET/scraper.log
```

## Development

### Interactive Shell

```bash
# Get a shell in the container
docker-compose run --rm scraper bash

# Run Ruby console
docker-compose run --rm scraper bin/run_scraper --debugger
```

### Debugging

Enable debugger and run specific sources:
```bash
docker-compose run --rm scraper bin/run_scraper \
  --debugger \
  --sources DnaLounge \
  --limit 5
```

## Architecture

```
ShowScraper/Scraper/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Orchestration config
├── .dockerignore          # Files to exclude from build
├── README.md              # This file
├── Gemfile                # Ruby dependencies
├── sources.json           # List of venues to scrape
├── .env.example           # Environment variables template
├── bin/
│   └── run_scraper        # Main entry point
└── scraper/
    ├── scraper.rb         # Scraper orchestration
    └── lib/
        ├── gcs.rb         # Google Cloud Storage interface
        ├── selenium_patches.rb  # Browser patches
        └── sources/       # Individual venue scrapers
            ├── dna_lounge.rb
            ├── fillmore.rb
            └── ...
```

## Resource Requirements

- **CPU**: 1-2 cores
- **Memory**: 1-2 GB (adjust based on number of sources)
- **Disk**: ~1 GB for image, minimal for runtime
- **Network**: Outbound HTTPS access required

## Security Notes

- Credentials are mounted read-only
- Container runs without database by default
- No exposed ports (offline process)
- Consider using Docker secrets for production
- Run as non-root user in production (add to Dockerfile)

## License

See parent project LICENSE file.
