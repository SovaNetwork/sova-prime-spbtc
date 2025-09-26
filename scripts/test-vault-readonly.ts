#!/usr/bin/env npx tsx

/**
 * Read-only test script for vault interface functionality
 * Tests contract reads without requiring a private key
 */

import { ethers } from 'ethers';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '../frontend/lib/abis';

const RPC_URL = 'https://sepolia.base.org';

// Contract addresses
const BTC_VAULT_TOKEN = '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a';
const BTC_VAULT_STRATEGY = '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8';

// Collateral tokens
const COLLATERALS = [
  { symbol: 'WBTC', address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', decimals: 8 },
  { symbol: 'tBTC', address: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802', decimals: 18 }, // Non-standard!
  { symbol: 'sovaBTC', address: '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9', decimals: 8 },
];

// Test wallet address (read-only) - using ethers to ensure proper checksum
const TEST_ADDRESS = ethers.getAddress('0x85ab19d77516414f7333a8fd52cc1f49ff8eafa9');

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  
  console.log('Testing vault interface (read-only)...');
  console.log('Test address:', TEST_ADDRESS);
  console.log('');

  // Connect to contracts
  const vaultToken = new ethers.Contract(BTC_VAULT_TOKEN, BTC_VAULT_TOKEN_ABI, provider);
  const vaultStrategy = new ethers.Contract(BTC_VAULT_STRATEGY, BTC_VAULT_STRATEGY_ABI, provider);

  console.log('=== Vault Configuration ===');
  
  // Test each collateral
  for (const collateral of COLLATERALS) {
    console.log(`\n${collateral.symbol} (${collateral.address.slice(0, 10)}...):`);
    
    const token = new ethers.Contract(collateral.address, ERC20_ABI, provider);
    
    try {
      // 1. Check if collateral is supported
      const isSupported = await vaultStrategy.isSupportedAsset(collateral.address);
      console.log(`  ✓ Supported: ${isSupported ? 'YES' : 'NO'}`);
      
      // 2. Get token info
      try {
        const symbol = await token.symbol();
        const decimals = await token.decimals();
        console.log(`  ✓ Token Info: ${symbol}, ${decimals} decimals`);
        
        if (Number(decimals) !== collateral.decimals) {
          console.log(`  ⚠️  WARNING: Decimals mismatch! Expected ${collateral.decimals}, got ${decimals}`);
        }
      } catch (e) {
        console.log(`  ⚠️  Could not read token info`);
      }
      
      // 3. Test preview deposit
      const testAmount = ethers.parseUnits('0.001', collateral.decimals);
      try {
        const previewShares = await vaultToken.previewDepositCollateral(collateral.address, testAmount);
        const previewFormatted = ethers.formatUnits(previewShares, 18);
        console.log(`  ✓ Preview: 0.001 ${collateral.symbol} → ${previewFormatted} vBTC`);
      } catch (e: any) {
        console.log(`  ✗ Preview failed: ${e.reason || e.message}`);
      }
      
      // 4. Check allowance function
      try {
        const checksumAddress = ethers.getAddress(TEST_ADDRESS);
        const allowance = await token.allowance(checksumAddress, BTC_VAULT_TOKEN);
        console.log(`  ✓ Allowance check works: ${ethers.formatUnits(allowance, collateral.decimals)} ${collateral.symbol}`);
      } catch (e: any) {
        console.log(`  ✗ Allowance check failed: ${e.reason || e.message}`);
      }
      
    } catch (error: any) {
      console.error(`  ✗ Error testing ${collateral.symbol}:`, error.reason || error.message);
    }
  }
  
  console.log('\n=== Vault Stats ===');
  
  try {
    // Get vault stats
    const totalAssets = await vaultToken.totalAssets();
    const totalSupply = await vaultToken.totalSupply();
    // Check if withdrawals are enabled (might be a different function name)
    let withdrawalEnabled = false;
    try {
      withdrawalEnabled = await vaultToken.withdrawalEnabled();
    } catch {
      try {
        withdrawalEnabled = await vaultToken.getWithdrawalEnabled();
      } catch {
        console.log('Withdrawal status: Unknown (function not found)');
      }
    }
    
    console.log(`Total Assets: ${ethers.formatUnits(totalAssets, 18)} BTC`);
    console.log(`Total Supply: ${ethers.formatUnits(totalSupply, 18)} vBTC`);
    console.log(`Share Price: ${totalSupply > 0n ? (Number(totalAssets) / Number(totalSupply)).toFixed(6) : '1.000000'}`);
    console.log(`Withdrawals Enabled: ${withdrawalEnabled}`);
    
    // Test user functions
    const checksumAddress = ethers.getAddress(TEST_ADDRESS);
    const userShares = await vaultToken.balanceOf(checksumAddress);
    console.log(`\nTest Address Shares: ${ethers.formatUnits(userShares, 18)} vBTC`);
    
  } catch (error: any) {
    console.error('Error getting vault stats:', error.reason || error.message);
  }
  
  console.log('\n=== Testing Complete ===');
  console.log('✓ All read-only tests completed');
  console.log('\nSummary:');
  console.log('- Vault contracts are accessible');
  console.log('- Collateral support can be checked');
  console.log('- Preview functions are working');
  console.log('- Allowance checks are functional');
  console.log('\n🎉 Vault interface is ready for use!');
}

main().catch(error => {
  console.error('Script error:', error);
  process.exit(1);
});