import { ponder } from "@/generated";

// Helper function to get date string
const getDateString = (timestamp: bigint): string => {
  const date = new Date(Number(timestamp) * 1000);
  return date.toISOString().split('T')[0];
};

// BtcVaultToken: Deposit event (ERC4626)
ponder.on("BtcVaultToken:Deposit", async ({ event, context }) => {
  const { db } = context;
  const { sender, owner, assets, shares } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash } = event.transaction;
  
  // Create or update user
  await db.users.upsert({
    id: owner.toLowerCase(),
    update: ({ current }) => ({
      totalDeposited: current.totalDeposited + assets,
      currentShares: current.currentShares + shares,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    }),
    create: {
      firstSeenBlock: blockNumber,
      firstSeenTimestamp: timestamp,
      totalDeposited: assets,
      totalWithdrawn: 0n,
      currentShares: shares,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    },
  });
  
  // Record deposit
  await db.deposits.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      sender: sender.toLowerCase(),
      owner: owner.toLowerCase(),
      assets,
      shares,
      collateralToken: null, // Will be set by collateralDeposits if applicable
      timestamp,
      blockNumber,
      txHash,
    },
  });
  
  // Update daily metrics
  const dateStr = getDateString(timestamp);
  await db.dailyMetrics.upsert({
    id: dateStr,
    update: ({ current }) => ({
      totalDeposits: current.totalDeposits + assets,
      depositCount: current.depositCount + 1,
    }),
    create: {
      date: dateStr,
      totalDeposits: assets,
      totalWithdrawals: 0n,
      depositCount: 1,
      withdrawalCount: 0,
      uniqueUsers: 0,
      avgSharePrice: 0n,
      endingTotalAssets: 0n,
      endingTotalSupply: 0n,
    },
  });
});

// BtcVaultToken: Withdraw event (ERC4626)
ponder.on("BtcVaultToken:Withdraw", async ({ event, context }) => {
  const { db } = context;
  const { sender, receiver, owner, assets, shares } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash } = event.transaction;
  
  // Update user
  await db.users.upsert({
    id: owner.toLowerCase(),
    update: ({ current }) => ({
      totalWithdrawn: current.totalWithdrawn + assets,
      currentShares: current.currentShares - shares,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    }),
    create: {
      firstSeenBlock: blockNumber,
      firstSeenTimestamp: timestamp,
      totalDeposited: 0n,
      totalWithdrawn: assets,
      currentShares: 0n - shares, // Shouldn't happen but handle it
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    },
  });
  
  // Record withdrawal
  await db.withdrawals.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      sender: sender.toLowerCase(),
      receiver: receiver.toLowerCase(),
      owner: owner.toLowerCase(),
      assets,
      shares,
      timestamp,
      blockNumber,
      txHash,
    },
  });
  
  // Update managed withdrawal if exists
  const withdrawalId = `${owner.toLowerCase()}-${timestamp}`;
  const managedWithdrawal = await db.managedWithdrawals.findUnique({
    id: withdrawalId,
  });
  
  if (managedWithdrawal && managedWithdrawal.status === "approved") {
    await db.managedWithdrawals.update({
      id: withdrawalId,
      data: {
        status: "completed",
        completionTimestamp: timestamp,
        completionTxHash: txHash,
      },
    });
  }
  
  // Update daily metrics
  const dateStr = getDateString(timestamp);
  await db.dailyMetrics.upsert({
    id: dateStr,
    update: ({ current }) => ({
      totalWithdrawals: current.totalWithdrawals + assets,
      withdrawalCount: current.withdrawalCount + 1,
    }),
    create: {
      date: dateStr,
      totalDeposits: 0n,
      totalWithdrawals: assets,
      depositCount: 0,
      withdrawalCount: 1,
      uniqueUsers: 0,
      avgSharePrice: 0n,
      endingTotalAssets: 0n,
      endingTotalSupply: 0n,
    },
  });
});

// BtcVaultToken: Transfer event (track share transfers)
ponder.on("BtcVaultToken:Transfer", async ({ event, context }) => {
  const { db } = context;
  const { from, to, value } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  
  // Skip mint (from = 0x0) and burn (to = 0x0) as they're handled by Deposit/Withdraw
  if (from === "0x0000000000000000000000000000000000000000" || 
      to === "0x0000000000000000000000000000000000000000") {
    return;
  }
  
  // Update sender balance
  await db.users.upsert({
    id: from.toLowerCase(),
    update: ({ current }) => ({
      currentShares: current.currentShares - value,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    }),
    create: {
      firstSeenBlock: blockNumber,
      firstSeenTimestamp: timestamp,
      totalDeposited: 0n,
      totalWithdrawn: 0n,
      currentShares: 0n - value,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    },
  });
  
  // Update receiver balance
  await db.users.upsert({
    id: to.toLowerCase(),
    update: ({ current }) => ({
      currentShares: current.currentShares + value,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    }),
    create: {
      firstSeenBlock: blockNumber,
      firstSeenTimestamp: timestamp,
      totalDeposited: 0n,
      totalWithdrawn: 0n,
      currentShares: value,
      lastActivityBlock: blockNumber,
      lastActivityTimestamp: timestamp,
    },
  });
});