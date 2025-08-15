#!/bin/bash

echo "🔧 Fixing Backend Services"
echo "=========================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Fix Ponder config to use SQLite for local development
echo -e "\n${YELLOW}1. Fixing Ponder configuration...${NC}"
cat > indexer/ponder.config.local.ts << 'EOF'
import { createConfig } from "@ponder/core";
import { http } from "viem";
import BtcVaultTokenAbi from "./abis/BtcVaultToken.json";
import BtcVaultStrategyAbi from "./abis/BtcVaultStrategy.json";

// Network configuration
const networks = {
  baseSepolia: {
    chainId: 84532,
    transport: http(process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org"),
  },
};

// Contract addresses (from deployment)
const contracts = {
  baseSepolia: {
    btcVaultToken: "0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a",
    btcVaultStrategy: "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8",
    startBlock: 19500000,
  },
};

const activeNetwork = "baseSepolia";
const networkConfig = networks[activeNetwork];
const contractConfig = contracts[activeNetwork];

export default createConfig({
  networks: {
    [activeNetwork]: networkConfig,
  },
  contracts: {
    BtcVaultToken: {
      network: activeNetwork,
      abi: BtcVaultTokenAbi as any,
      address: contractConfig.btcVaultToken as \`0x\${string}\`,
      startBlock: contractConfig.startBlock,
    },
    BtcVaultStrategy: {
      network: activeNetwork,
      abi: BtcVaultStrategyAbi as any,
      address: contractConfig.btcVaultStrategy as \`0x\${string}\`,
      startBlock: contractConfig.startBlock,
    },
  },
  database: {
    kind: "sqlite",
  },
});
EOF
echo -e "${GREEN}✓ Created local Ponder config with SQLite${NC}"

# 2. Fix scheduler TypeScript issues
echo -e "\n${YELLOW}2. Fixing Scheduler TypeScript configuration...${NC}"
cat > services/scheduler/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "../..",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "allowJs": false,
    "noEmit": false,
    "incremental": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "baseUrl": "../..",
    "paths": {
      "@/*": ["./lib/*"]
    }
  },
  "include": [
    "src/**/*",
    "../../lib/abis.ts",
    "../../lib/services/blockchainService.ts"
  ],
  "exclude": ["node_modules", "dist"]
}
EOF
echo -e "${GREEN}✓ Fixed TypeScript configuration${NC}"

# 3. Install scheduler dependencies
echo -e "\n${YELLOW}3. Installing Scheduler dependencies...${NC}"
cd services/scheduler
npm install --legacy-peer-deps
cd ../..
echo -e "${GREEN}✓ Scheduler dependencies installed${NC}"

# 4. Create a simple test script for Ponder
echo -e "\n${YELLOW}4. Creating Ponder test script...${NC}"
cat > indexer/test-local.sh << 'EOF'
#!/bin/bash
# Use local config with SQLite for testing
cp ponder.config.local.ts ponder.config.ts
npm start
EOF
chmod +x indexer/test-local.sh
echo -e "${GREEN}✓ Created Ponder test script${NC}"

# 5. Create docker-compose for local development with SQLite
echo -e "\n${YELLOW}5. Creating simplified docker-compose for testing...${NC}"
cat > docker-compose.local.yml << 'EOF'
version: '3.8'

services:
  # Ponder Indexer with SQLite
  indexer:
    build:
      context: .
      dockerfile: Dockerfile.indexer
    ports:
      - "42069:42069"
    environment:
      - BASE_SEPOLIA_RPC_URL=${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}
      - NETWORK=baseSepolia
      - NODE_ENV=development
    volumes:
      - ./indexer/ponder.config.local.ts:/app/indexer/ponder.config.ts
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:42069/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # PostgreSQL for scheduler only
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: sovabtc
      POSTGRES_PASSWORD: sovabtc123
      POSTGRES_DB: sovabtc
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sovabtc"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Scheduler Service
  scheduler:
    build:
      context: .
      dockerfile: Dockerfile.scheduler
    ports:
      - "3001:3001"
    environment:
      - DATABASE_URL=postgresql://sovabtc:sovabtc123@postgres:5432/sovabtc
      - BASE_SEPOLIA_RPC_URL=${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}
      - BASE_VAULT_TOKEN_ADDRESS=0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a
      - BASE_VAULT_STRATEGY_ADDRESS=0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8
      - NETWORK=baseSepolia
      - NODE_ENV=development
      - PORT=3001
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

volumes:
  postgres_data:
EOF
echo -e "${GREEN}✓ Created simplified docker-compose.local.yml${NC}"

echo -e "\n${GREEN}=========================="
echo "✅ Services Fixed!"
echo "=========================="
echo ""
echo "Next steps to test locally:"
echo "1. Test Ponder locally: cd indexer && ./test-local.sh"
echo "2. Test with Docker: docker-compose -f docker-compose.local.yml up --build"
echo "3. Check endpoints:"
echo "   - Indexer GraphQL: http://localhost:42069/graphql"
echo "   - Scheduler Health: http://localhost:3001/health"
echo ""
echo "For production deployment with PostgreSQL:"
echo "   docker-compose --env-file .env.docker up --build"
echo "==========================${NC}"