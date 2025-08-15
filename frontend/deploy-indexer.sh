#!/bin/bash

# Deploy Ponder Indexer to Railway

echo "Deploying Ponder Indexer to Railway..."

# Create temporary directory for indexer deployment
mkdir -p deploy-indexer
cd deploy-indexer

# Copy necessary files
cp -r ../indexer .
cp ../Dockerfile.indexer Dockerfile

# Create railway.json for this specific service
cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "numReplicas": 1,
    "healthcheckPath": "/health",
    "healthcheckTimeout": 10,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3,
    "port": 42069
  }
}
EOF

echo "Files prepared for deployment. Deploy with:"
echo "cd deploy-indexer && railway up --detach"