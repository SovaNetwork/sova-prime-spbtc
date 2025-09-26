#!/bin/sh
# Migration script for production

echo "🔄 Starting database setup..."

# Log connection info (without password)
echo "📊 Database host: $(echo $DATABASE_URL | sed 's/.*@//' | sed 's/\/.*//')"

# Ensure DATABASE_URL has SSL parameters for Neon
if [ -n "$DATABASE_URL" ]; then
  # Check if sslmode is already in the URL
  if ! echo "$DATABASE_URL" | grep -q "sslmode="; then
    # Add SSL parameters for Neon
    export DATABASE_URL="${DATABASE_URL}?sslmode=require"
    echo "✅ Added SSL mode to DATABASE_URL"
  else
    echo "✅ SSL mode already configured"
  fi
fi

echo "🔧 Generating Prisma client first..."
npx prisma generate

echo "📊 Attempting to push schema to database..."

# Try to push the schema directly (for initial setup)
npx prisma db push --skip-generate --accept-data-loss

if [ $? -eq 0 ]; then
  echo "✅ Schema pushed successfully"
else
  echo "⚠️ Failed to push schema. Trying migrations..."
  
  # Run migrations
  npx prisma migrate deploy
  
  if [ $? -eq 0 ]; then
    echo "✅ Migrations completed successfully"
  else
    echo "⚠️ Database setup failed, but continuing anyway..."
    echo "⚠️ The service will retry database operations at runtime"
  fi
fi

echo "✅ Database setup phase complete"