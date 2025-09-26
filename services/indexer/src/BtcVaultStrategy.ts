import { ponder } from "@/generated";

// Helper function to extract chainId from network name
const getChainInfo = (networkName: string) => {
  const chainIds: Record<string, number> = {
    'baseSepolia': 84532,
    'ethereum': 1,
    'base': 8453,
    'arbitrum': 42161,
    'optimism': 10,
    'sepolia': 11155111,
  };
  return { chainId: chainIds[networkName] || 84532, network: networkName };
};

// Get enabled networks from environment
const enabledNetworks = (process.env.PONDER_ENABLED_NETWORKS || "baseSepolia").split(',').map(n => n.trim());

// Create handlers for each enabled network
enabledNetworks.forEach(networkName => {
  const contractName = `BtcVaultStrategy_${networkName}`;
  const { chainId } = getChainInfo(networkName);

  // BtcVaultStrategy: CollateralDeposited event
  ponder.on(`${contractName}:CollateralDeposited`, async ({ event, context }) => {
    const { db } = context;
    const { depositor, token, amount } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash } = event.transaction;
    
    // Record collateral deposit
    await db.collateralDeposits.create({
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        depositor: depositor.toLowerCase(),
        collateralToken: token.toLowerCase(),
        amount,
        mintedShares: 0n, // Not available in this event
        timestamp,
        blockNumber,
        txHash,
      },
    });
    
    // Update the related deposit with collateral token info
    // Find deposit from same transaction and chain
    const deposits = await db.deposits.findMany({
      where: { txHash, chainId },
    });
    
    if (deposits.length > 0) {
      await db.deposits.update({
        id: deposits[0].id,
        data: {
          collateralToken: token.toLowerCase(),
        },
      });
    }
  });

  // BtcVaultStrategy: CollateralAdded event
  ponder.on(`${contractName}:CollateralAdded`, async ({ event, context }) => {
    const { db } = context;
    const { token, decimals } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash, from } = event.transaction;
    
    await db.collateralChanges.create({
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        collateralToken: token.toLowerCase(),
        action: "added",
        admin: from.toLowerCase(),
        timestamp,
        blockNumber,
        txHash,
      },
    });
  });

  // BtcVaultStrategy: CollateralRemoved event
  ponder.on(`${contractName}:CollateralRemoved`, async ({ event, context }) => {
    const { db } = context;
    const { token } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash, from } = event.transaction;
    
    await db.collateralChanges.create({
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        collateralToken: token.toLowerCase(),
        action: "removed",
        admin: from.toLowerCase(),
        timestamp,
        blockNumber,
        txHash,
      },
    });
  });

  // BtcVaultStrategy: LiquidityAdded event
  ponder.on(`${contractName}:LiquidityAdded`, async ({ event, context }) => {
    const { db } = context;
    const { amount } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash } = event.transaction;
    
    await db.liquidityEvents.create({
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        eventType: "added",
        amount,
        totalLiquidity: 0n, // Would need to track cumulative
        timestamp,
        blockNumber,
        txHash,
      },
    });
  });

  // BtcVaultStrategy: LiquidityRemoved event
  ponder.on(`${contractName}:LiquidityRemoved`, async ({ event, context }) => {
    const { db } = context;
    const { amount } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash } = event.transaction;
    
    await db.liquidityEvents.create({
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        eventType: "removed",
        amount,
        totalLiquidity: 0n, // Would need to track cumulative
        timestamp,
        blockNumber,
        txHash,
      },
    });
  });
});

// Note: WithdrawalApproved event doesn't exist in current ABI
// Managed withdrawals are tracked through other events in the new architecture

// Create periodic snapshots on major events
export async function createVaultSnapshot(context: any, blockNumber: bigint, timestamp: bigint, chainId: number) {
  const { db, client } = context;
  
  // Only create snapshots every 100 blocks to avoid too many records
  if (blockNumber % 100n !== 0n) return;
  
  try {
    // Read total assets and supply from contract
    // This would require contract calls which Ponder doesn't directly support
    // So we'll track this through events instead
    
    // For now, create a placeholder snapshot with chainId
    await db.vaultSnapshots.upsert({
      id: `${chainId}-${blockNumber.toString()}`,
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

// Note: Snapshot creation is called from BtcVaultToken event handlers
// to avoid duplicate event handler registration