import { createSchema } from "@ponder/core";

export default createSchema((p) => ({
  // User tracking - renamed from btcUsers to users to match event handlers
  users: p.createTable({
    id: p.string(), // chainId-userAddress
    userAddress: p.string(),
    chainId: p.int(),
    firstSeenBlock: p.bigint(),
    firstSeenTimestamp: p.bigint(),
    totalDeposited: p.bigint(),
    totalWithdrawn: p.bigint(),
    currentShares: p.bigint(),
    lastActivityBlock: p.bigint(),
    lastActivityTimestamp: p.bigint(),
  }),

  // Keep btcUsers for backwards compatibility if needed
  btcUsers: p.createTable({
    id: p.string(), // user address
    firstSeenBlock: p.bigint(),
    firstSeenTimestamp: p.bigint(),
    totalDeposited: p.bigint(),
    totalWithdrawn: p.bigint(),
    currentShares: p.bigint(),
    lastActivityBlock: p.bigint(),
    lastActivityTimestamp: p.bigint(),
  }),

  // Deposit events from BtcVaultToken (ERC4626 Deposit event) - renamed to match handlers
  deposits: p.createTable({
    id: p.string(), // chainId-txHash-logIndex
    chainId: p.int(),
    sender: p.string(),
    owner: p.string(),
    assets: p.bigint(),
    shares: p.bigint(),
    collateralToken: p.string().optional(), // From depositCollateral events
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Keep btcDeposits for backwards compatibility
  btcDeposits: p.createTable({
    id: p.string(), // txHash-logIndex
    sender: p.string(),
    owner: p.string(),
    assets: p.bigint(),
    shares: p.bigint(),
    collateralToken: p.string().optional(), // From depositCollateral events
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Withdraw events from BtcVaultToken (ERC4626 Withdraw event) - renamed to match handlers
  withdrawals: p.createTable({
    id: p.string(), // chainId-txHash-logIndex
    chainId: p.int(),
    sender: p.string(),
    receiver: p.string(),
    owner: p.string(),
    assets: p.bigint(),
    shares: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Keep btcWithdrawals for backwards compatibility
  btcWithdrawals: p.createTable({
    id: p.string(), // txHash-logIndex
    sender: p.string(),
    receiver: p.string(),
    owner: p.string(),
    assets: p.bigint(),
    shares: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Transfer events for tracking shares
  btcTransfers: p.createTable({
    id: p.string(), // txHash-logIndex
    from: p.string(),
    to: p.string(),
    value: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Collateral updates from strategy
  collateralUpdates: p.createTable({
    id: p.string(), // txHash-logIndex
    collateralToken: p.string(),
    isSupported: p.boolean(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Liquidity events from strategy
  liquidityEvents: p.createTable({
    id: p.string(), // txHash-logIndex
    eventType: p.string(), // 'added' or 'removed'
    amount: p.bigint(),
    totalLiquidity: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // NAV updates from strategy reports
  navUpdates: p.createTable({
    id: p.string(), // txHash-logIndex
    nav: p.bigint(),
    gain: p.bigint(),
    loss: p.bigint(),
    totalAssets: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Strategy report events
  strategyReports: p.createTable({
    id: p.string(), // txHash-logIndex
    nav: p.bigint(),
    gain: p.bigint(),
    loss: p.bigint(),
    totalAssets: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Vault metrics (hourly snapshots)
  vaultMetrics: p.createTable({
    id: p.string(), // timestamp-hour
    totalAssets: p.bigint(),
    totalShares: p.bigint(),
    sharePrice: p.bigint(),
    totalUsers: p.int(),
    activeUsers: p.int(), // Active in last 24h
    totalDeposits: p.bigint(),
    totalWithdrawals: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
  }),

  // User position tracking
  userPositions: p.createTable({
    id: p.string(), // userAddress-blockNumber
    userAddress: p.string(),
    shares: p.bigint(),
    assets: p.bigint(), // Calculated based on share price
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
  }),

  // Transaction logs for debugging
  transactionLogs: p.createTable({
    id: p.string(), // txHash
    blockNumber: p.bigint(),
    timestamp: p.bigint(),
    from: p.string(),
    to: p.string(),
    value: p.bigint(),
    gasUsed: p.bigint().optional(),
    gasPrice: p.bigint().optional(),
    status: p.int(), // 1 for success, 0 for failure
  }),

  // Collateral changes tracking (MISSING - causing crash)
  collateralChanges: p.createTable({
    id: p.string(), // txHash-logIndex
    collateralToken: p.string(),
    action: p.string(), // 'added' or 'removed'
    admin: p.string(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Collateral deposits from strategy
  collateralDeposits: p.createTable({
    id: p.string(), // txHash-logIndex
    depositor: p.string(),
    collateralToken: p.string(),
    amount: p.bigint(),
    mintedShares: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
    txHash: p.string(),
  }),

  // Daily metrics tracking
  dailyMetrics: p.createTable({
    id: p.string(), // chainId-date string YYYY-MM-DD
    chainId: p.int(),
    date: p.string(),
    totalDeposits: p.bigint(),
    totalWithdrawals: p.bigint(),
    depositCount: p.int(),
    withdrawalCount: p.int(),
    uniqueUsers: p.int(),
    avgSharePrice: p.bigint(),
    endingTotalAssets: p.bigint(),
    endingTotalSupply: p.bigint(),
  }),

  // Managed withdrawals tracking
  managedWithdrawals: p.createTable({
    id: p.string(), // userAddress-timestamp
    userAddress: p.string(),
    shares: p.bigint(),
    status: p.string(), // 'pending', 'approved', 'completed'
    requestTimestamp: p.bigint(),
    approvalTimestamp: p.bigint().optional(),
    completionTimestamp: p.bigint().optional(),
    completionTxHash: p.string().optional(),
  }),

  // Vault snapshots for historical data
  vaultSnapshots: p.createTable({
    id: p.string(), // blockNumber
    totalAssets: p.bigint(),
    totalSupply: p.bigint(),
    sharePrice: p.bigint(),
    sovaBtcBalance: p.bigint(),
    timestamp: p.bigint(),
    blockNumber: p.bigint(),
  }),
}));