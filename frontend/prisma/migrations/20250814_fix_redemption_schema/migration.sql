-- First add the missing enum value (if not exists)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'EXPIRED' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'RedemptionStatus')) THEN
        ALTER TYPE "RedemptionStatus" ADD VALUE 'EXPIRED';
    END IF;
END $$;

-- Drop existing table and recreate with correct schema
DROP TABLE IF EXISTS "sovabtc_redemption_requests";

-- Create the redemption requests table with correct schema
CREATE TABLE "sovabtc_redemption_requests" (
    "id" TEXT NOT NULL,
    "deploymentId" TEXT NOT NULL,
    "userAddress" TEXT NOT NULL,
    "shareAmount" BIGINT NOT NULL,
    "expectedAssets" BIGINT NOT NULL,
    "minAssetsOut" BIGINT NOT NULL,
    "signature" TEXT NOT NULL,
    "nonce" BIGINT NOT NULL,
    "deadline" TIMESTAMP(3) NOT NULL,
    "status" "RedemptionStatus" NOT NULL DEFAULT 'PENDING',
    "priority" INTEGER NOT NULL DEFAULT 5,
    "queuePosition" INTEGER NULL,
    "processedAt" TIMESTAMP(3) NULL,
    "txHash" TEXT NULL,
    "actualAssets" BIGINT NULL,
    "gasCost" BIGINT NULL,
    "adminNotes" TEXT NULL,
    "rejectionReason" TEXT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_redemption_requests_pkey" PRIMARY KEY ("id")
);

-- Create indexes for performance
CREATE INDEX "sovabtc_redemption_requests_userAddress_idx" 
    ON "sovabtc_redemption_requests"("userAddress");
CREATE INDEX "sovabtc_redemption_requests_status_idx" 
    ON "sovabtc_redemption_requests"("status");
CREATE INDEX "sovabtc_redemption_requests_deploymentId_idx" 
    ON "sovabtc_redemption_requests"("deploymentId");
CREATE INDEX "sovabtc_redemption_requests_priority_idx" 
    ON "sovabtc_redemption_requests"("priority");
CREATE INDEX "sovabtc_redemption_requests_queuePosition_idx" 
    ON "sovabtc_redemption_requests"("queuePosition") 
    WHERE "queuePosition" IS NOT NULL;

-- Create unique constraint for nonce per deployment
CREATE UNIQUE INDEX "sovabtc_redemption_requests_deploymentId_nonce_key" 
    ON "sovabtc_redemption_requests"("deploymentId", "nonce");

-- Add foreign key constraint
ALTER TABLE "sovabtc_redemption_requests" 
    ADD CONSTRAINT "sovabtc_redemption_requests_deploymentId_fkey" 
    FOREIGN KEY ("deploymentId") REFERENCES "sovabtc_deployments"("id") 
    ON DELETE RESTRICT ON UPDATE CASCADE;