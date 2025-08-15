-- CreateEnum
CREATE TYPE "public"."DeploymentStatus" AS ENUM ('NOT_DEPLOYED', 'PENDING', 'ACTIVE', 'DEPRECATED');

-- CreateEnum
CREATE TYPE "public"."ActivityType" AS ENUM ('DEPLOYMENT_CREATED', 'DEPLOYMENT_UPDATED', 'COLLATERAL_ADDED', 'COLLATERAL_REMOVED', 'STATUS_CHANGED', 'METRICS_UPDATED', 'USER_DEPOSIT', 'USER_WITHDRAWAL');

-- CreateTable
CREATE TABLE "public"."sovabtc_networks" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "rpcUrl" TEXT NOT NULL,
    "blockExplorer" TEXT NOT NULL,
    "nativeCurrency" JSONB NOT NULL,
    "isTestnet" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_networks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_deployments" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "vaultStrategy" TEXT NOT NULL,
    "vaultToken" TEXT NOT NULL,
    "priceOracle" TEXT,
    "status" "public"."DeploymentStatus" NOT NULL DEFAULT 'NOT_DEPLOYED',
    "deployer" TEXT,
    "blockNumber" INTEGER,
    "transactionHash" TEXT,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_deployments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_collaterals" (
    "id" TEXT NOT NULL,
    "deploymentId" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "address" TEXT NOT NULL,
    "decimals" INTEGER NOT NULL,
    "oracleId" TEXT,
    "logoUri" TEXT,
    "coingeckoId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_collaterals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_token_registry" (
    "id" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "addresses" JSONB NOT NULL,
    "decimals" INTEGER NOT NULL,
    "logoUri" TEXT,
    "coingeckoId" TEXT,
    "category" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_token_registry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_deployment_metrics" (
    "id" TEXT NOT NULL,
    "deploymentId" TEXT NOT NULL,
    "tvl" DECIMAL(30,10) NOT NULL,
    "totalSupply" DECIMAL(30,10) NOT NULL,
    "totalAssets" DECIMAL(30,10) NOT NULL,
    "sharePrice" DECIMAL(30,10) NOT NULL,
    "apy" DECIMAL(10,4),
    "users" INTEGER NOT NULL DEFAULT 0,
    "transactions" INTEGER NOT NULL DEFAULT 0,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sovabtc_deployment_metrics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_network_metrics" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "blockHeight" BIGINT NOT NULL,
    "gasPrice" BIGINT NOT NULL,
    "isOnline" BOOLEAN NOT NULL DEFAULT true,
    "latency" INTEGER,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sovabtc_network_metrics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."sovabtc_activities" (
    "id" TEXT NOT NULL,
    "deploymentId" TEXT NOT NULL,
    "type" "public"."ActivityType" NOT NULL,
    "description" TEXT NOT NULL,
    "metadata" JSONB,
    "txHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sovabtc_activities_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_networks_chainId_key" ON "public"."sovabtc_networks"("chainId");

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_deployments_chainId_key" ON "public"."sovabtc_deployments"("chainId");

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_collaterals_chainId_address_key" ON "public"."sovabtc_collaterals"("chainId", "address");

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_collaterals_deploymentId_symbol_chainId_key" ON "public"."sovabtc_collaterals"("deploymentId", "symbol", "chainId");

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_token_registry_symbol_key" ON "public"."sovabtc_token_registry"("symbol");

-- CreateIndex
CREATE INDEX "sovabtc_deployment_metrics_deploymentId_timestamp_idx" ON "public"."sovabtc_deployment_metrics"("deploymentId", "timestamp");

-- CreateIndex
CREATE INDEX "sovabtc_network_metrics_chainId_timestamp_idx" ON "public"."sovabtc_network_metrics"("chainId", "timestamp");

-- CreateIndex
CREATE INDEX "sovabtc_activities_deploymentId_createdAt_idx" ON "public"."sovabtc_activities"("deploymentId", "createdAt");

-- AddForeignKey
ALTER TABLE "public"."sovabtc_deployments" ADD CONSTRAINT "sovabtc_deployments_chainId_fkey" FOREIGN KEY ("chainId") REFERENCES "public"."sovabtc_networks"("chainId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."sovabtc_collaterals" ADD CONSTRAINT "sovabtc_collaterals_deploymentId_fkey" FOREIGN KEY ("deploymentId") REFERENCES "public"."sovabtc_deployments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."sovabtc_deployment_metrics" ADD CONSTRAINT "sovabtc_deployment_metrics_deploymentId_fkey" FOREIGN KEY ("deploymentId") REFERENCES "public"."sovabtc_deployments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."sovabtc_network_metrics" ADD CONSTRAINT "sovabtc_network_metrics_chainId_fkey" FOREIGN KEY ("chainId") REFERENCES "public"."sovabtc_networks"("chainId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."sovabtc_activities" ADD CONSTRAINT "sovabtc_activities_deploymentId_fkey" FOREIGN KEY ("deploymentId") REFERENCES "public"."sovabtc_deployments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
