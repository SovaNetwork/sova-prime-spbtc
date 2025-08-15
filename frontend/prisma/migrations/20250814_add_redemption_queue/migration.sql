-- CreateEnum
CREATE TYPE "RedemptionStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED');

-- AlterEnum
ALTER TYPE "ActivityType" ADD VALUE 'REDEMPTION_REQUEST';
ALTER TYPE "ActivityType" ADD VALUE 'REDEMPTION_APPROVED';
ALTER TYPE "ActivityType" ADD VALUE 'REDEMPTION_REJECTED';
ALTER TYPE "ActivityType" ADD VALUE 'REDEMPTION_PROCESSED';
ALTER TYPE "ActivityType" ADD VALUE 'REDEMPTION_CANCELLED';

-- CreateTable
CREATE TABLE "sovabtc_redemption_requests" (
    "id" TEXT NOT NULL,
    "userAddress" TEXT NOT NULL,
    "shares" TEXT NOT NULL,
    "receiver" TEXT NOT NULL,
    "signature" TEXT NOT NULL,
    "signedAt" TIMESTAMP(3) NOT NULL,
    "nonce" TEXT NOT NULL,
    "deadline" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL,
    "deploymentId" TEXT NOT NULL,
    "status" "RedemptionStatus" NOT NULL DEFAULT 'PENDING',
    "approvedBy" TEXT,
    "approvedAt" TIMESTAMP(3),
    "processedTxHash" TEXT,
    "processedAt" TIMESTAMP(3),
    "rejectedReason" TEXT,
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sovabtc_redemption_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "sovabtc_redemption_requests_userAddress_idx" ON "sovabtc_redemption_requests"("userAddress");

-- CreateIndex
CREATE INDEX "sovabtc_redemption_requests_status_idx" ON "sovabtc_redemption_requests"("status");

-- CreateIndex
CREATE INDEX "sovabtc_redemption_requests_deploymentId_idx" ON "sovabtc_redemption_requests"("deploymentId");

-- CreateIndex
CREATE INDEX "sovabtc_redemption_requests_chainId_idx" ON "sovabtc_redemption_requests"("chainId");

-- CreateIndex
CREATE UNIQUE INDEX "sovabtc_redemption_requests_userAddress_nonce_key" ON "sovabtc_redemption_requests"("userAddress", "nonce");

-- AddForeignKey
ALTER TABLE "sovabtc_redemption_requests" ADD CONSTRAINT "sovabtc_redemption_requests_deploymentId_fkey" FOREIGN KEY ("deploymentId") REFERENCES "sovabtc_deployments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;