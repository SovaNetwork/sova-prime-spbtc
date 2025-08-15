import { ponder } from "@/generated";

// Helper function to get date string
const getDateString = (timestamp: bigint): string => {
  const date = new Date(Number(timestamp) * 1000);
  return date.toISOString().split('T')[0];
};

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
  const contractName = `BtcVaultToken_${networkName}`;
  const { chainId } = getChainInfo(networkName);

  // BtcVaultToken: Deposit event (ERC4626)
  ponder.on(`${contractName}:Deposit`, async ({ event, context }) => {
    const { db } = context;
    const { sender, owner, assets, shares } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash } = event.transaction;
    
    const userKey = `${chainId}-${owner.toLowerCase()}`;
    
    // Create or update user
    await db.users.upsert({
      id: userKey,
      update: ({ current }) => ({
        totalDeposited: current.totalDeposited + assets,
        currentShares: current.currentShares + shares,
        lastActivityBlock: blockNumber,
        lastActivityTimestamp: timestamp,
      }),
      create: {
        userAddress: owner.toLowerCase(),
        chainId,
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
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        chainId,
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
    const dailyKey = `${chainId}-${dateStr}`;
    await db.dailyMetrics.upsert({
      id: dailyKey,
      update: ({ current }) => ({
        totalDeposits: current.totalDeposits + assets,
        depositCount: current.depositCount + 1,
      }),
      create: {
        chainId,
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
  ponder.on(`${contractName}:Withdraw`, async ({ event, context }) => {
    const { db } = context;
    const { sender, receiver, owner, assets, shares } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    const { hash: txHash } = event.transaction;
    
    const userKey = `${chainId}-${owner.toLowerCase()}`;
    
    // Update user
    await db.users.upsert({
      id: userKey,
      update: ({ current }) => ({
        totalWithdrawn: current.totalWithdrawn + assets,
        currentShares: current.currentShares - shares,
        lastActivityBlock: blockNumber,
        lastActivityTimestamp: timestamp,
      }),
      create: {
        userAddress: owner.toLowerCase(),
        chainId,
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
      id: `${chainId}-${txHash}-${event.log.logIndex}`,
      data: {
        chainId,
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
    const withdrawalId = `${chainId}-${owner.toLowerCase()}-${timestamp}`;
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
    const dailyKey = `${chainId}-${dateStr}`;
    await db.dailyMetrics.upsert({
      id: dailyKey,
      update: ({ current }) => ({
        totalWithdrawals: current.totalWithdrawals + assets,
        withdrawalCount: current.withdrawalCount + 1,
      }),
      create: {
        chainId,
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
  ponder.on(`${contractName}:Transfer`, async ({ event, context }) => {
    const { db } = context;
    const { from, to, value } = event.args;
    const { timestamp, number: blockNumber } = event.block;
    
    // Skip mint (from = 0x0) and burn (to = 0x0) as they're handled by Deposit/Withdraw
    if (from === "0x0000000000000000000000000000000000000000" || 
        to === "0x0000000000000000000000000000000000000000") {
      return;
    }
    
    const fromKey = `${chainId}-${from.toLowerCase()}`;
    const toKey = `${chainId}-${to.toLowerCase()}`;
    
    // Update sender balance
    await db.users.upsert({
      id: fromKey,
      update: ({ current }) => ({
        currentShares: current.currentShares - value,
        lastActivityBlock: blockNumber,
        lastActivityTimestamp: timestamp,
      }),
      create: {
        userAddress: from.toLowerCase(),
        chainId,
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
      id: toKey,
      update: ({ current }) => ({
        currentShares: current.currentShares + value,
        lastActivityBlock: blockNumber,
        lastActivityTimestamp: timestamp,
      }),
      create: {
        userAddress: to.toLowerCase(),
        chainId,
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
});