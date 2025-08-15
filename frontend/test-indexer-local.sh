#!/bin/bash

# Test the indexer locally without Docker
echo "Testing Ponder Indexer locally..."

cd indexer

# Set minimal environment variables
export BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
export PORT=42069

# Run the indexer in dev mode for 30 seconds to check for errors
timeout 30 npm run dev || true

echo "Test completed. Check output above for any errors."