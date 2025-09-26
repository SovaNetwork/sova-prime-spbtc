#!/bin/sh
# Startup script for Ponder indexer with database setup

echo "🔄 Starting Ponder indexer setup..."

# Ensure DATABASE_URL has SSL parameters for Neon
if [ -n "$PONDER_DATABASE_URL" ]; then
  # Check if sslmode is already in the URL
  if ! echo "$PONDER_DATABASE_URL" | grep -q "sslmode="; then
    # Add SSL parameters for Neon
    export PONDER_DATABASE_URL="${PONDER_DATABASE_URL}?sslmode=require"
    echo "✅ Added SSL mode to PONDER_DATABASE_URL"
  else
    echo "✅ SSL mode already configured"
  fi
elif [ -n "$DATABASE_URL" ]; then
  # Use DATABASE_URL if PONDER_DATABASE_URL is not set
  export PONDER_DATABASE_URL="$DATABASE_URL"
  if ! echo "$PONDER_DATABASE_URL" | grep -q "sslmode="; then
    export PONDER_DATABASE_URL="${PONDER_DATABASE_URL}?sslmode=require"
  fi
  echo "✅ Using DATABASE_URL for Ponder"
fi

# Log connection info (without password)
echo "📊 Database host: $(echo $PONDER_DATABASE_URL | sed 's/.*@//' | sed 's/\/.*//')"

echo "🚀 Starting Ponder indexer..."
echo "📊 GraphQL endpoint will be available at http://localhost:42069/graphql"
echo "ℹ️  Ponder will create its own database tables automatically"

# Check if we're using PostgreSQL or SQLite
if [ -n "$PONDER_DATABASE_URL" ] || [ -n "$DATABASE_URL" ]; then
  echo "📊 Using PostgreSQL database"
else
  echo "📊 Using SQLite database (local development mode)"
fi

# Start Ponder with proper error handling
exec npm start

# If Ponder exits, log the error
if [ $? -ne 0 ]; then
  echo "❌ Ponder indexer exited with error"
  exit 1
fi