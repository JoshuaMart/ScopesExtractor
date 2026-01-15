#!/bin/bash
set -e

# Ensure db directory exists and has correct permissions
mkdir -p /app/db /app/tmp

# Run migrations if database doesn't exist
if [ ! -f /app/db/scopes.db ]; then
  echo "Database not found. Running migrations..."
  bundle exec bin/scopes_extractor migrate
fi

# Execute the main command
exec "$@"
