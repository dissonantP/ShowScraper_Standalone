FROM ruby:3.3-slim

# Install Firefox, build tools, cron, and architecture-appropriate Geckodriver
RUN apt-get update && apt-get install -y \
    build-essential \
    firefox-esr \
    cron \
    wget \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then GECKO_ARCH="linux64"; \
       elif [ "$ARCH" = "aarch64" ]; then GECKO_ARCH="linux-aarch64"; \
       else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && wget -qO- https://github.com/mozilla/geckodriver/releases/download/v0.35.0/geckodriver-v0.35.0-$GECKO_ARCH.tar.gz | tar xzC /usr/local/bin \
    && chmod +x /usr/local/bin/geckodriver \
    && apt-get remove -y wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile ./
RUN bundle install

# Copy application code
COPY scraper ./scraper
COPY bin ./bin
COPY sources.json ./
COPY .env.example ./
COPY crontab /etc/cron.d/scraper-cron

RUN chmod +x bin/run_scraper bin/cron_wrapper.sh \
    && chmod 0644 /etc/cron.d/scraper-cron \
    && crontab /etc/cron.d/scraper-cron

# Set environment variables
ENV GECKODRIVER_PATH=/usr/local/bin/geckodriver
ENV HEADLESS=true
ENV NO_DB=true
ENV NO_GCS=false
ENV PRINT_EVENTS=true
ENV PRINT_FULL_DETAIL=false
ENV RESCUE_SCRAPING_ERRORS=true

# Create directories for volumes
RUN mkdir -p credentials logs

# Default: run cron in foreground
CMD ["cron", "-f"]
