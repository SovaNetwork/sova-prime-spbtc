import { ponder } from "ponder:registry";
import { 
  users, 
  deposits, 
  redemptionRequests,
  processedRedemptions,
  claimedRedemptions,
  vaultSnapshots,
  priceUpdates,
  adminOperations,
  dailyMetrics
} from "ponder:schema";

// Helper to get asset symbol
const getAssetSymbol = (address: string): string => {
  const symbols: Record<string, string> = {
    "0xe44b2870eFcd6Bb3C9305808012621f438e9636D": "WBTC",
    "0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802": "TBTC",
    "0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9": "sovaBTC",
  };
  return symbols[address] || "UNKNOWN";
};

// Helper to get date string
const getDateString = (timestamp: bigint): string => {
  const date = new Date(Number(timestamp) * 1000);
  return date.toISOString().split('T')[0];
};

// MultiBTCVault: Deposit event
ponder.on("MultiBTCVault:Deposit", async ({ event, context }) => {
  const { db } = context;
  const { sender, owner, assets, shares } = event.args;
  const asset = event.log.address; // The vault address for now, will need to track asset separately
  
  // Create or update user
  await db.users.upsert({
    id: owner.toLowerCase(),
    update: ({ current }) => ({
      totalDeposited: current.totalDeposited + assets,
      shareBalance: current.shareBalance + shares,
    }),
    create: {
      firstSeenBlock: event.block.number,
      firstSeenTimestamp: event.block.timestamp,
      totalDeposited: assets,
      totalRedeemed: 0n,
      shareBalance: shares,
    },
  });

  // Record deposit
  await db.deposits.create({
    id: `${event.transaction.hash}-${event.log.logIndex}`,
    data: {
      user: owner.toLowerCase(),
      asset: asset.toLowerCase(),
      assetSymbol: "mcBTC", // This is mcBTC shares
      amount: assets,
      shares: shares,
      timestamp: event.block.timestamp,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    },
  });

  // Update daily metrics
  const dateStr = getDateString(event.block.timestamp);
  await db.dailyMetrics.upsert({
    id: dateStr,
    update: ({ current }) => ({
      totalDeposits: current.totalDeposits + assets,
      depositCount: current.depositCount + 1,
    }),
    create: {
      date: dateStr,
      totalDeposits: assets,
      totalRedemptions: 0n,
      depositCount: 1,
      redemptionCount: 0,
      uniqueUsers: 0,
      avgSharePrice: 0n,
      endingTotalAssets: 0n,
      endingTotalSupply: 0n,
    },
  });
});

// MultiBTCVault: Withdraw event
ponder.on("MultiBTCVault:Withdraw", async ({ event, context }) => {
  const { db } = context;
  const { sender, receiver, owner, assets, shares } = event.args;

  // Update user
  await db.users.upsert({
    id: owner.toLowerCase(),
    update: ({ current }) => ({
      totalRedeemed: current.totalRedeemed + assets,
      shareBalance: current.shareBalance - shares,
    }),
    create: {
      firstSeenBlock: event.block.number,
      firstSeenTimestamp: event.block.timestamp,
      totalDeposited: 0n,
      totalRedeemed: assets,
      shareBalance: 0n - shares, // This shouldn't happen but handle it
    },
  });

  // Update daily metrics
  const dateStr = getDateString(event.block.timestamp);
  await db.dailyMetrics.upsert({
    id: dateStr,
    update: ({ current }) => ({
      totalRedemptions: current.totalRedemptions + assets,
      redemptionCount: current.redemptionCount + 1,
    }),
    create: {
      date: dateStr,
      totalDeposits: 0n,
      totalRedemptions: assets,
      depositCount: 0,
      redemptionCount: 1,
      uniqueUsers: 0,
      avgSharePrice: 0n,
      endingTotalAssets: 0n,
      endingTotalSupply: 0n,
    },
  });
});

// ManagedRedemptionQueue: RedemptionRequested event
ponder.on("ManagedRedemptionQueue:RedemptionRequested", async ({ event, context }) => {
  const { db } = context;
  const { requestId, user, shares, claimableAfter } = event.args;

  await db.redemptionRequests.create({
    id: requestId.toString(),
    data: {
      requestId: requestId,
      user: user.toLowerCase(),
      shares: shares,
      requestedAt: event.block.timestamp,
      claimableAfter: claimableAfter,
      processed: false,
      claimed: false,
      processedTxHash: null,
      claimedTxHash: null,
      redeemableAmount: null,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    },
  });
});

// ManagedRedemptionQueue: RedemptionProcessed event
ponder.on("ManagedRedemptionQueue:RedemptionProcessed", async ({ event, context }) => {
  const { db } = context;
  const { requestId, shares, redeemableAmount } = event.args;

  // Update redemption request
  await db.redemptionRequests.update({
    id: requestId.toString(),
    data: {
      processed: true,
      processedTxHash: event.transaction.hash,
      redeemableAmount: redeemableAmount,
    },
  });

  // Get the request to find the user
  const request = await db.redemptionRequests.findUnique({
    id: requestId.toString(),
  });

  if (request) {
    // Record processed redemption
    await db.processedRedemptions.create({
      id: `${event.transaction.hash}-${event.log.logIndex}`,
      data: {
        requestId: requestId,
        user: request.user,
        shares: shares,
        redeemableAmount: redeemableAmount,
        timestamp: event.block.timestamp,
        blockNumber: event.block.number,
        txHash: event.transaction.hash,
      },
    });
  }
});

// ManagedRedemptionQueue: RedemptionClaimed event
ponder.on("ManagedRedemptionQueue:RedemptionClaimed", async ({ event, context }) => {
  const { db } = context;
  const { requestId, user, amount } = event.args;

  // Update redemption request
  await db.redemptionRequests.update({
    id: requestId.toString(),
    data: {
      claimed: true,
      claimedTxHash: event.transaction.hash,
    },
  });

  // Record claimed redemption
  await db.claimedRedemptions.create({
    id: `${event.transaction.hash}-${event.log.logIndex}`,
    data: {
      requestId: requestId,
      user: user.toLowerCase(),
      amount: amount,
      timestamp: event.block.timestamp,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    },
  });
});

// MultiBTCVault: VaultPaused event
ponder.on("MultiBTCVault:VaultPaused", async ({ event, context }) => {
  const { db } = context;

  await db.adminOperations.create({
    id: `${event.transaction.hash}-${event.log.logIndex}`,
    data: {
      operation: "pause",
      admin: event.transaction.from.toLowerCase(),
      details: "Vault paused",
      timestamp: event.block.timestamp,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    },
  });
});

// MultiBTCVault: VaultUnpaused event
ponder.on("MultiBTCVault:VaultUnpaused", async ({ event, context }) => {
  const { db } = context;

  await db.adminOperations.create({
    id: `${event.transaction.hash}-${event.log.logIndex}`,
    data: {
      operation: "unpause",
      admin: event.transaction.from.toLowerCase(),
      details: "Vault unpaused",
      timestamp: event.block.timestamp,
      blockNumber: event.block.number,
      txHash: event.transaction.hash,
    },
  });
});

// Note: Vault snapshots can be created on each Deposit/Withdraw event instead
// since Ponder doesn't support generic block handlers