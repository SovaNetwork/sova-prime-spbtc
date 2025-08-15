import { ponder } from "@/generated";

// BtcVaultStrategy: CollateralDeposited event
ponder.on("BtcVaultStrategy:CollateralDeposited", async ({ event, context }) => {
  const { db } = context;
  const { depositor, collateralToken, amount, mintedShares } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash } = event.transaction;
  
  // Record collateral deposit
  await db.collateralDeposits.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      depositor: depositor.toLowerCase(),
      collateralToken: collateralToken.toLowerCase(),
      amount,
      mintedShares,
      timestamp,
      blockNumber,
      txHash,
    },
  });
  
  // Update the related deposit with collateral token info
  // Find deposit from same transaction
  const deposits = await db.deposits.findMany({
    where: { txHash },
  });
  
  if (deposits.length > 0) {
    await db.deposits.update({
      id: deposits[0].id,
      data: {
        collateralToken: collateralToken.toLowerCase(),
      },
    });
  }
});

// BtcVaultStrategy: CollateralAdded event
ponder.on("BtcVaultStrategy:CollateralAdded", async ({ event, context }) => {
  const { db } = context;
  const { collateral } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash, from } = event.transaction;
  
  await db.collateralChanges.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      collateralToken: collateral.toLowerCase(),
      action: "added",
      admin: from.toLowerCase(),
      timestamp,
      blockNumber,
      txHash,
    },
  });
});

// BtcVaultStrategy: CollateralRemoved event
ponder.on("BtcVaultStrategy:CollateralRemoved", async ({ event, context }) => {
  const { db } = context;
  const { collateral } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash, from } = event.transaction;
  
  await db.collateralChanges.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      collateralToken: collateral.toLowerCase(),
      action: "removed",
      admin: from.toLowerCase(),
      timestamp,
      blockNumber,
      txHash,
    },
  });
});

// BtcVaultStrategy: LiquidityAdded event
ponder.on("BtcVaultStrategy:LiquidityAdded", async ({ event, context }) => {
  const { db } = context;
  const { amount } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash, from } = event.transaction;
  
  await db.liquidityEvents.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      action: "added",
      amount,
      admin: from.toLowerCase(),
      timestamp,
      blockNumber,
      txHash,
    },
  });
});

// BtcVaultStrategy: LiquidityRemoved event
ponder.on("BtcVaultStrategy:LiquidityRemoved", async ({ event, context }) => {
  const { db } = context;
  const { amount } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash, from } = event.transaction;
  
  await db.liquidityEvents.create({
    id: `${txHash}-${event.log.logIndex}`,
    data: {
      action: "removed",
      amount,
      admin: from.toLowerCase(),
      timestamp,
      blockNumber,
      txHash,
    },
  });
});

// BtcVaultStrategy: WithdrawalApproved event
ponder.on("BtcVaultStrategy:WithdrawalApproved", async ({ event, context }) => {
  const { db } = context;
  const { user, shares } = event.args;
  const { timestamp, number: blockNumber } = event.block;
  const { hash: txHash, from } = event.transaction;
  
  const withdrawalId = `${user.toLowerCase()}-pending`;
  
  // Update or create managed withdrawal record
  await db.managedWithdrawals.upsert({
    id: withdrawalId,
    update: {
      approvedShares: shares,
      status: "approved",
      approvalTimestamp: timestamp,
      approvalTxHash: txHash,
    },
    create: {
      user: user.toLowerCase(),
      requestedShares: shares,
      approvedShares: shares,
      status: "approved",
      requestTimestamp: timestamp,
      approvalTimestamp: timestamp,
      completionTimestamp: null,
      requestTxHash: txHash,
      approvalTxHash: txHash,
      completionTxHash: null,
    },
  });
});

// Create periodic snapshots on major events
async function createVaultSnapshot(context: any, blockNumber: bigint, timestamp: bigint) {
  const { db, client } = context;
  
  // Only create snapshots every 100 blocks to avoid too many records
  if (blockNumber % 100n !== 0n) return;
  
  try {
    // Read total assets and supply from contract
    // This would require contract calls which Ponder doesn't directly support
    // So we'll track this through events instead
    
    // For now, create a placeholder snapshot
    await db.vaultSnapshots.upsert({
      id: blockNumber.toString(),
      update: {
        timestamp,
      },
      create: {
        totalAssets: 0n, // Would need to track through events
        totalSupply: 0n, // Would need to track through events
        sharePrice: 1000000n, // 1:1 initially (scaled by 1e6)
        sovaBtcBalance: 0n, // Would need to track through liquidity events
        timestamp,
        blockNumber,
      },
    });
  } catch (error) {
    console.error("Error creating vault snapshot:", error);
  }
}

// Call snapshot creation on major events
ponder.on("BtcVaultToken:Deposit", async ({ event, context }) => {
  await createVaultSnapshot(context, event.block.number, event.block.timestamp);
});

ponder.on("BtcVaultToken:Withdraw", async ({ event, context }) => {
  await createVaultSnapshot(context, event.block.number, event.block.timestamp);
});