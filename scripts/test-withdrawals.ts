#!/usr/bin/env node

/**
 * Test script for withdrawal functionality
 * 
 * This script tests:
 * 1. Reading available liquidity from strategy
 * 2. Calling approveTokenWithdrawal on strategy
 * 3. Simulating batchRedeemShares on token
 * 4. Verifying balance changes
 */

import { createPublicClient, createWalletClient, http, parseUnits, formatUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { sepolia } from 'viem/chains';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '../frontend/lib/abis';

// Contract addresses (update these with actual deployed addresses)
const CONTRACTS = {
  btcVaultToken: '0x...' as const, // TODO: Add actual address
  btcVaultStrategy: '0x...' as const, // TODO: Add actual address
  sovaBTC: '0x...' as const, // TODO: Add actual address
};

// Configuration
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;
const RPC_URL = process.env.RPC_URL || 'https://sepolia.infura.io/v3/your-key';

if (!PRIVATE_KEY) {
  console.error('PRIVATE_KEY environment variable is required');
  process.exit(1);
}

// Setup clients
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(RPC_URL),
});

const account = privateKeyToAccount(PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http(RPC_URL),
});

async function main() {
  console.log('🔍 Testing BTC Vault Withdrawal System');
  console.log('=====================================\n');

  try {
    // Step 1: Read current state
    console.log('📊 Reading current vault state...');
    
    const [availableLiquidity, totalAssets, totalSupply, userBalance] = await Promise.all([
      publicClient.readContract({
        address: CONTRACTS.btcVaultStrategy,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'availableLiquidity',
      }),
      publicClient.readContract({
        address: CONTRACTS.btcVaultToken,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'totalAssets',
      }),
      publicClient.readContract({
        address: CONTRACTS.btcVaultToken,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'totalSupply',
      }),
      publicClient.readContract({
        address: CONTRACTS.btcVaultToken,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'balanceOf',
        args: [account.address],
      }),
    ]);

    console.log(`  Available Liquidity: ${formatUnits(availableLiquidity, 8)} sovaBTC`);
    console.log(`  Total Assets: ${formatUnits(totalAssets, 8)} BTC`);
    console.log(`  Total Supply: ${formatUnits(totalSupply, 18)} vBTC`);
    console.log(`  User Balance: ${formatUnits(userBalance, 18)} vBTC`);
    console.log('');

    // Step 2: Check if user has shares to redeem
    if (userBalance === 0n) {
      console.log('⚠️ User has no vBTC shares to redeem. Skipping redemption test.');
      return;
    }

    // Step 3: Calculate redemption amount (redeem 10% of user's shares)
    const redeemShares = userBalance / 10n;
    const expectedAssets = await publicClient.readContract({
      address: CONTRACTS.btcVaultToken,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'previewRedeem',
      args: [redeemShares],
    });

    console.log(`🎯 Planning to redeem: ${formatUnits(redeemShares, 18)} vBTC`);
    console.log(`   Expected assets: ${formatUnits(expectedAssets, 8)} sovaBTC`);
    console.log('');

    // Step 4: Check if there's enough liquidity
    if (expectedAssets > availableLiquidity) {
      console.log(`❌ Insufficient liquidity for redemption:`);
      console.log(`   Required: ${formatUnits(expectedAssets, 8)} sovaBTC`);
      console.log(`   Available: ${formatUnits(availableLiquidity, 8)} sovaBTC`);
      return;
    }

    // Step 5: Approve token withdrawal (admin function)
    console.log('🔐 Step 1: Approving token withdrawal...');
    const approveHash = await walletClient.writeContract({
      address: CONTRACTS.btcVaultStrategy,
      abi: BTC_VAULT_STRATEGY_ABI,
      functionName: 'approveTokenWithdrawal',
    });
    
    console.log(`   Transaction hash: ${approveHash}`);
    
    // Wait for confirmation
    const approveReceipt = await publicClient.waitForTransactionReceipt({ 
      hash: approveHash 
    });
    
    if (approveReceipt.status === 'success') {
      console.log('   ✅ Approval successful');
    } else {
      console.log('   ❌ Approval failed');
      return;
    }
    console.log('');

    // Step 6: Execute redemption
    console.log('💰 Step 2: Executing redemption...');
    
    // For testing, we'll do a single redemption (batchRedeemShares with array of 1)
    const redeemHash = await walletClient.writeContract({
      address: CONTRACTS.btcVaultToken,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'batchRedeemShares',
      args: [
        [redeemShares], // shares array
        [account.address], // receivers array
        [account.address], // owners array
        [expectedAssets], // minAssets array
      ],
    });

    console.log(`   Transaction hash: ${redeemHash}`);
    
    // Wait for confirmation
    const redeemReceipt = await publicClient.waitForTransactionReceipt({ 
      hash: redeemHash 
    });
    
    if (redeemReceipt.status === 'success') {
      console.log('   ✅ Redemption successful');
    } else {
      console.log('   ❌ Redemption failed');
      return;
    }
    console.log('');

    // Step 7: Verify final balances
    console.log('🔍 Verifying final state...');
    
    const [newAvailableLiquidity, newUserBalance] = await Promise.all([
      publicClient.readContract({
        address: CONTRACTS.btcVaultStrategy,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'availableLiquidity',
      }),
      publicClient.readContract({
        address: CONTRACTS.btcVaultToken,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'balanceOf',
        args: [account.address],
      }),
    ]);

    console.log(`  New Available Liquidity: ${formatUnits(newAvailableLiquidity, 8)} sovaBTC`);
    console.log(`  New User Balance: ${formatUnits(newUserBalance, 18)} vBTC`);
    console.log(`  Liquidity Used: ${formatUnits(availableLiquidity - newAvailableLiquidity, 8)} sovaBTC`);
    console.log(`  Shares Burned: ${formatUnits(userBalance - newUserBalance, 18)} vBTC`);
    console.log('');

    console.log('✅ Withdrawal test completed successfully!');

  } catch (error) {
    console.error('❌ Error during withdrawal test:', error);
    
    if (error instanceof Error) {
      console.error('Error details:', error.message);
    }
    
    process.exit(1);
  }
}

// Additional utility functions for testing
async function checkContractFunctions() {
  console.log('🔧 Checking available contract functions...');
  
  try {
    // Test read functions
    console.log('📖 Testing read functions...');
    
    const maxRedeem = await publicClient.readContract({
      address: CONTRACTS.btcVaultToken,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'maxRedeem',
      args: [account.address],
    });
    
    console.log(`   Max redeemable: ${formatUnits(maxRedeem, 18)} vBTC`);
    
    // More function tests...
    console.log('✅ Function checks completed');
    
  } catch (error) {
    console.error('❌ Function check error:', error);
  }
}

// Run the test
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

export { main, checkContractFunctions };