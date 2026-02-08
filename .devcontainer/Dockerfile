FROM ruby:3.3

# Install full development environment
RUN apt-get update && apt-get install -y \
    build-essential \
    firefox-esr \
    git \
    vim \
    curl \
    wget \
    cron \
    procps \
    sudo \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then GECKO_ARCH="linux64"; \
       elif [ "$ARCH" = "aarch64" ]; then GECKO_ARCH="linux-aarch64"; \
       else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && wget -qO- https://github.com/mozilla/geckodriver/releases/download/v0.35.0/geckodriver-v0.35.0-$GECKO_ARCH.tar.gz | tar xzC /usr/local/bin \
    && chmod +x /usr/local/bin/geckodriver \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile ./
RUN bundle install

# Set environment variables for development
ENV GECKODRIVER_PATH=/usr/local/bin/geckodriver
ENV HEADLESS=true
ENV NO_DB=true
ENV NO_GCS=false
ENV PRINT_EVENTS=true
ENV PRINT_FULL_DETAIL=false
ENV RESCUE_SCRAPING_ERRORS=true

# Create directories
RUN mkdir -p credentials logs

# Default command for development
CMD ["sleep", "infinity"]
