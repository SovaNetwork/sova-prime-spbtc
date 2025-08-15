-- Create tables for the Scheduler service
-- These are separate from Ponder tables

-- Run this in Neon SQL editor to create the scheduler tables

-- Networks table
CREATE TABLE IF NOT EXISTS "sovabtc_networks" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "chainId" INTEGER UNIQUE NOT NULL,
    "name" TEXT NOT NULL,
    "rpcUrl" TEXT NOT NULL,
    "blockExplorer" TEXT NOT NULL,
    "nativeCurrency" JSONB NOT NULL,
    "isTestnet" BOOLEAN DEFAULT false,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Deployments table
CREATE TABLE IF NOT EXISTS "sovabtc_deployments" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "chainId" INTEGER NOT NULL,
    "vaultStrategy" TEXT NOT NULL,
    "vaultToken" TEXT NOT NULL,
    "priceOracle" TEXT,
    "status" TEXT DEFAULT 'NOT_DEPLOYED',
    "deployer" TEXT,
    "blockNumber" INTEGER,
    "transactionHash" TEXT,
    "verified" BOOLEAN DEFAULT false,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("chainId") REFERENCES "sovabtc_networks"("chainId")
);

-- Collaterals table
CREATE TABLE IF NOT EXISTS "sovabtc_collaterals" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "deploymentId" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "symbol" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "decimals" INTEGER NOT NULL,
    "isActive" BOOLEAN DEFAULT true,
    "isVerified" BOOLEAN DEFAULT false,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("deploymentId") REFERENCES "sovabtc_deployments"("id"),
    UNIQUE("chainId", "address")
);

-- Token Registry table
CREATE TABLE IF NOT EXISTS "sovabtc_token_registry" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "symbol" TEXT UNIQUE NOT NULL,
    "name" TEXT NOT NULL,
    "decimals" INTEGER NOT NULL,
    "addresses" JSONB NOT NULL,
    "category" TEXT NOT NULL,
    "coingeckoId" TEXT,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Deployment Metrics table
CREATE TABLE IF NOT EXISTS "sovabtc_deployment_metrics" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "deploymentId" TEXT NOT NULL,
    "tvl" TEXT NOT NULL,
    "totalSupply" TEXT,
    "totalAssets" TEXT,
    "sharePrice" TEXT,
    "apy" DECIMAL,
    "users" INTEGER DEFAULT 0,
    "transactions" INTEGER DEFAULT 0,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("deploymentId") REFERENCES "sovabtc_deployments"("id")
);

-- Network Metrics table
CREATE TABLE IF NOT EXISTS "sovabtc_network_metrics" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "chainId" INTEGER NOT NULL,
    "blockHeight" BIGINT NOT NULL,
    "gasPrice" BIGINT NOT NULL,
    "isOnline" BOOLEAN DEFAULT true,
    "latency" INTEGER,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("chainId") REFERENCES "sovabtc_networks"("chainId")
);

-- Activities table
CREATE TABLE IF NOT EXISTS "sovabtc_activities" (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "deploymentId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("deploymentId") REFERENCES "sovabtc_deployments"("id")
);

-- Insert initial data for Base Sepolia
INSERT INTO "sovabtc_networks" ("chainId", "name", "rpcUrl", "blockExplorer", "nativeCurrency", "isTestnet")
VALUES (
    84532,
    'Base Sepolia',
    'https://sepolia.base.org',
    'https://sepolia.basescan.org',
    '{"name": "ETH", "symbol": "ETH", "decimals": 18}',
    true
) ON CONFLICT (chainId) DO NOTHING;

INSERT INTO "sovabtc_deployments" ("chainId", "vaultStrategy", "vaultToken", "status", "verified")
VALUES (
    84532,
    '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
    '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
    'ACTIVE',
    true
) ON CONFLICT DO NOTHING;

-- Check if tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE 'sovabtc_%'
ORDER BY table_name;