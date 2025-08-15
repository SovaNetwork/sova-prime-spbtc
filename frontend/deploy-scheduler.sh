#!/bin/bash

# Deploy Scheduler to Railway

echo "Deploying Scheduler to Railway..."

# Create temporary directory for scheduler deployment
mkdir -p deploy-scheduler
cd deploy-scheduler

# Copy necessary files
cp -r ../services ../lib ../prisma ../package*.json .
cp ../Dockerfile.scheduler Dockerfile

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
    "port": 3001
  }
}
EOF

echo "Files prepared for deployment. Deploy with:"
echo "cd deploy-scheduler && railway up --detach"