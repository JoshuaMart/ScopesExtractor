FROM --platform=linux/amd64 ruby:3.4.7-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle install --without development test

# Copy application code
COPY . .

# Create non-root user and set ownership
RUN groupadd -r scopes && useradd -r -g scopes scopes && \
    chown -R scopes:scopes /app && \
    mkdir -p /app/db /app/tmp && \
    chown -R scopes:scopes /app/db /app/tmp

# Switch to non-root user
USER scopes

# Expose API port
EXPOSE 4567

# Health check - verify process is running without triggering auth logs
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f "bin/scopes_extractor" > /dev/null || exit 1

# Default command (can be overridden)
CMD ["bundle", "exec", "bin/scopes_extractor", "help"]
