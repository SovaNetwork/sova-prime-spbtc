#!/bin/bash

# Set environment variables for Railway services
# Usage: ./set-railway-vars.sh <service-id>

SERVICE_ID=${1:-f0747ec5-3ae4-49d2-b98c-8420850fe7a9}

echo "Setting environment variables for service: $SERVICE_ID"

# Database Configuration (update with your actual database URL)
railway variables set DATABASE_URL="postgresql://neondb_owner:xxxxx@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require" --service $SERVICE_ID
railway variables set DIRECT_DATABASE_URL="postgresql://neondb_owner:xxxxx@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require" --service $SERVICE_ID

# Network Configuration (update with your actual RPC URL)
railway variables set BASE_SEPOLIA_RPC_URL="https://base-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY" --service $SERVICE_ID
railway variables set NETWORK="baseSepolia" --service $SERVICE_ID

# Contract Addresses
railway variables set BASE_VAULT_TOKEN_ADDRESS="0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a" --service $SERVICE_ID
railway variables set BASE_VAULT_STRATEGY_ADDRESS="0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8" --service $SERVICE_ID
railway variables set NEXT_PUBLIC_VAULT_ADDRESS="0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a" --service $SERVICE_ID
railway variables set NEXT_PUBLIC_STRATEGY_ADDRESS="0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8" --service $SERVICE_ID

# Service Configuration
railway variables set NODE_ENV="production" --service $SERVICE_ID
railway variables set PORT="3000" --service $SERVICE_ID

# For Ponder Indexer
railway variables set PONDER_DATABASE_URL="postgresql://neondb_owner:xxxxx@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require" --service $SERVICE_ID
railway variables set BASE_START_BLOCK="19500000" --service $SERVICE_ID

# For Scheduler
railway variables set CRON_ENABLED="true" --service $SERVICE_ID
railway variables set SCHEDULER_PORT="3001" --service $SERVICE_ID

echo "Environment variables set successfully!"
echo "Please update the DATABASE_URL and RPC_URL with your actual values"