-- CreateTable
CREATE TABLE "rate_limit_violations" (
    "id" TEXT NOT NULL,
    "ip" TEXT NOT NULL,
    "endpoint" TEXT NOT NULL,
    "userAgent" TEXT,
    "userId" TEXT,
    "count" INTEGER NOT NULL DEFAULT 1,
    "blocked" BOOLEAN NOT NULL DEFAULT false,
    "blockUntil" TIMESTAMP(3),
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rate_limit_violations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "rate_limit_violations_ip_endpoint_key" ON "rate_limit_violations"("ip", "endpoint");

-- CreateIndex
CREATE INDEX "rate_limit_violations_timestamp_idx" ON "rate_limit_violations"("timestamp");

-- CreateIndex
CREATE INDEX "rate_limit_violations_blocked_idx" ON "rate_limit_violations"("blocked");