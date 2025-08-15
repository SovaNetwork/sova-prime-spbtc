import { onchainTable } from "ponder";

// User activity tracking
export const users = onchainTable("users", (t) => ({
  id: t.text().primaryKey(), // address
  firstSeenBlock: t.bigint().notNull(),
  firstSeenTimestamp: t.bigint().notNull(),
  totalDeposited: t.bigint().notNull(),
  totalRedeemed: t.bigint().notNull(),
  shareBalance: t.bigint().notNull(),
}));

// Deposit events
export const deposits = onchainTable("deposits", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  user: t.text().notNull(),
  asset: t.text().notNull(),
  assetSymbol: t.text().notNull(),
  amount: t.bigint().notNull(),
  shares: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Redemption requests
export const redemptionRequests = onchainTable("redemption_requests", (t) => ({
  id: t.text().primaryKey(), // requestId
  requestId: t.bigint().notNull(),
  user: t.text().notNull(),
  shares: t.bigint().notNull(),
  requestedAt: t.bigint().notNull(),
  claimableAfter: t.bigint().notNull(),
  processed: t.boolean().notNull(),
  claimed: t.boolean().notNull(),
  processedTxHash: t.text(),
  claimedTxHash: t.text(),
  redeemableAmount: t.bigint(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Processed redemptions
export const processedRedemptions = onchainTable("processed_redemptions", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  requestId: t.bigint().notNull(),
  user: t.text().notNull(),
  shares: t.bigint().notNull(),
  redeemableAmount: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Claimed redemptions
export const claimedRedemptions = onchainTable("claimed_redemptions", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  requestId: t.bigint().notNull(),
  user: t.text().notNull(),
  amount: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Vault metrics snapshots
export const vaultSnapshots = onchainTable("vault_snapshots", (t) => ({
  id: t.text().primaryKey(), // blockNumber
  totalAssets: t.bigint().notNull(),
  totalSupply: t.bigint().notNull(),
  sharePrice: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
}));

// Collateral balances
export const collateralBalances = onchainTable("collateral_balances", (t) => ({
  id: t.text().primaryKey(), // blockNumber-asset
  asset: t.text().notNull(),
  assetSymbol: t.text().notNull(),
  balance: t.bigint().notNull(),
  valueInBTC: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
}));

// Price updates
export const priceUpdates = onchainTable("price_updates", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  oldPrice: t.bigint().notNull(),
  newPrice: t.bigint().notNull(),
  reporter: t.text().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Admin operations
export const adminOperations = onchainTable("admin_operations", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  operation: t.text().notNull(), // pause, unpause, forceProcess, etc
  admin: t.text().notNull(),
  details: t.text(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Daily aggregates
export const dailyMetrics = onchainTable("daily_metrics", (t) => ({
  id: t.text().primaryKey(), // date (YYYY-MM-DD)
  date: t.text().notNull(),
  totalDeposits: t.bigint().notNull(),
  totalRedemptions: t.bigint().notNull(),
  depositCount: t.integer().notNull(),
  redemptionCount: t.integer().notNull(),
  uniqueUsers: t.integer().notNull(),
  avgSharePrice: t.bigint().notNull(),
  endingTotalAssets: t.bigint().notNull(),
  endingTotalSupply: t.bigint().notNull(),
}));