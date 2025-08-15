#!/bin/bash

echo "🔧 Testing Backend Services Locally"
echo "==================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test if PostgreSQL is available
echo -e "\n${YELLOW}1. Testing PostgreSQL connection...${NC}"
if command -v psql &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL client found${NC}"
else
    echo -e "${RED}✗ PostgreSQL client not found. Install with: brew install postgresql${NC}"
fi

# Test Node.js version
echo -e "\n${YELLOW}2. Testing Node.js version...${NC}"
NODE_VERSION=$(node --version)
if [[ $NODE_VERSION == v20* ]] || [[ $NODE_VERSION == v18* ]]; then
    echo -e "${GREEN}✓ Node.js version: $NODE_VERSION${NC}"
else
    echo -e "${RED}✗ Node.js version $NODE_VERSION may not be compatible. Recommend v20.x${NC}"
fi

# Test Ponder indexer
echo -e "\n${YELLOW}3. Testing Ponder Indexer...${NC}"
cd indexer
if [ -f "package.json" ]; then
    echo -e "${GREEN}✓ Found indexer package.json${NC}"
    
    # Check if dependencies are installed
    if [ -d "node_modules" ]; then
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠ Dependencies not installed. Run: npm install${NC}"
    fi
    
    # Test build
    echo "Testing Ponder schema..."
    if npm run codegen 2>/dev/null; then
        echo -e "${GREEN}✓ Schema validation passed${NC}"
    else
        echo -e "${RED}✗ Schema validation failed${NC}"
    fi
else
    echo -e "${RED}✗ Indexer package.json not found${NC}"
fi
cd ..

# Test Scheduler
echo -e "\n${YELLOW}4. Testing Scheduler Service...${NC}"
cd services/scheduler
if [ -f "package.json" ]; then
    echo -e "${GREEN}✓ Found scheduler package.json${NC}"
    
    # Check if dependencies are installed
    if [ -d "node_modules" ]; then
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠ Dependencies not installed. Run: npm install${NC}"
    fi
    
    # Test TypeScript build
    echo "Testing TypeScript build..."
    if npm run typecheck 2>/dev/null; then
        echo -e "${GREEN}✓ TypeScript check passed${NC}"
    else
        echo -e "${RED}✗ TypeScript check failed${NC}"
    fi
else
    echo -e "${RED}✗ Scheduler package.json not found${NC}"
fi
cd ../..

# Test Docker
echo -e "\n${YELLOW}5. Testing Docker...${NC}"
if docker version &> /dev/null; then
    echo -e "${GREEN}✓ Docker is running${NC}"
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
    echo -e "  Docker version: $DOCKER_VERSION"
else
    echo -e "${RED}✗ Docker is not running. Start Docker Desktop${NC}"
fi

# Summary
echo -e "\n${YELLOW}==================================${NC}"
echo -e "${YELLOW}Summary:${NC}"
echo -e "${YELLOW}==================================${NC}"

# Check environment variables
echo -e "\n${YELLOW}6. Checking Environment Variables...${NC}"
if [ -f ".env.docker" ]; then
    echo -e "${GREEN}✓ .env.docker file exists${NC}"
    
    # Check key variables
    source .env.docker
    
    if [ -n "$DATABASE_URL" ]; then
        echo -e "${GREEN}✓ DATABASE_URL configured${NC}"
    else
        echo -e "${RED}✗ DATABASE_URL not set${NC}"
    fi
    
    if [ -n "$BASE_SEPOLIA_RPC_URL" ]; then
        echo -e "${GREEN}✓ BASE_SEPOLIA_RPC_URL configured${NC}"
    else
        echo -e "${RED}✗ BASE_SEPOLIA_RPC_URL not set${NC}"
    fi
else
    echo -e "${RED}✗ .env.docker file not found${NC}"
fi

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Install missing dependencies: npm install (in both indexer and services/scheduler)"
echo "2. Start Docker Desktop if not running"
echo "3. Run: docker-compose --env-file .env.docker up --build"
echo "4. Check health endpoints:"
echo "   - Indexer: http://localhost:42069/health"
echo "   - Scheduler: http://localhost:3001/health"