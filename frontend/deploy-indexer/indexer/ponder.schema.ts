import { onchainTable } from "@ponder/core";

// User tracking
export const users = onchainTable("btc_users", (t) => ({
  id: t.text().primaryKey(), // user address
  firstSeenBlock: t.bigint().notNull(),
  firstSeenTimestamp: t.bigint().notNull(),
  totalDeposited: t.bigint().notNull().default(0n),
  totalWithdrawn: t.bigint().notNull().default(0n),
  currentShares: t.bigint().notNull().default(0n),
  lastActivityBlock: t.bigint().notNull(),
  lastActivityTimestamp: t.bigint().notNull(),
}));

// Deposit events from BtcVaultToken (ERC4626 Deposit event)
export const deposits = onchainTable("btc_deposits", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  sender: t.text().notNull(),
  owner: t.text().notNull(),
  assets: t.bigint().notNull(),
  shares: t.bigint().notNull(),
  collateralToken: t.text(), // From depositCollateral events
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Withdraw events from BtcVaultToken (ERC4626 Withdraw event)
export const withdrawals = onchainTable("btc_withdrawals", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  sender: t.text().notNull(),
  receiver: t.text().notNull(),
  owner: t.text().notNull(),
  assets: t.bigint().notNull(),
  shares: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Collateral deposits from BtcVaultStrategy
export const collateralDeposits = onchainTable("btc_collateral_deposits", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  depositor: t.text().notNull(),
  collateralToken: t.text().notNull(),
  amount: t.bigint().notNull(),
  mintedShares: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Managed withdrawals (approval tracking)
export const managedWithdrawals = onchainTable("btc_managed_withdrawals", (t) => ({
  id: t.text().primaryKey(), // user-timestamp
  user: t.text().notNull(),
  requestedShares: t.bigint().notNull(),
  approvedShares: t.bigint(),
  status: t.text().notNull(), // "pending", "approved", "completed"
  requestTimestamp: t.bigint().notNull(),
  approvalTimestamp: t.bigint(),
  completionTimestamp: t.bigint(),
  requestTxHash: t.text().notNull(),
  approvalTxHash: t.text(),
  completionTxHash: t.text(),
}));

// Collateral configuration changes
export const collateralChanges = onchainTable("btc_collateral_changes", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  collateralToken: t.text().notNull(),
  action: t.text().notNull(), // "added" or "removed"
  admin: t.text().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Liquidity management events
export const liquidityEvents = onchainTable("btc_liquidity_events", (t) => ({
  id: t.text().primaryKey(), // txHash-logIndex
  action: t.text().notNull(), // "added" or "removed"
  amount: t.bigint().notNull(),
  admin: t.text().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
  txHash: t.text().notNull(),
}));

// Vault snapshots (periodic state)
export const vaultSnapshots = onchainTable("btc_vault_snapshots", (t) => ({
  id: t.text().primaryKey(), // blockNumber
  totalAssets: t.bigint().notNull(),
  totalSupply: t.bigint().notNull(),
  sharePrice: t.bigint().notNull(), // assets per share (scaled)
  sovaBtcBalance: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
}));

// Daily metrics aggregation
export const dailyMetrics = onchainTable("btc_daily_metrics", (t) => ({
  id: t.text().primaryKey(), // date (YYYY-MM-DD)
  date: t.text().notNull(),
  totalDeposits: t.bigint().notNull().default(0n),
  totalWithdrawals: t.bigint().notNull().default(0n),
  depositCount: t.integer().notNull().default(0),
  withdrawalCount: t.integer().notNull().default(0),
  uniqueUsers: t.integer().notNull().default(0),
  avgSharePrice: t.bigint().notNull().default(0n),
  endingTotalAssets: t.bigint().notNull().default(0n),
  endingTotalSupply: t.bigint().notNull().default(0n),
}));

// Collateral balances tracking
export const collateralBalances = onchainTable("btc_collateral_balances", (t) => ({
  id: t.text().primaryKey(), // blockNumber-collateralToken
  collateralToken: t.text().notNull(),
  balance: t.bigint().notNull(),
  timestamp: t.bigint().notNull(),
  blockNumber: t.bigint().notNull(),
}));