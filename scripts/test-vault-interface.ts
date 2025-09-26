#!/usr/bin/env npx tsx

/**
 * Test script for vault interface functionality
 * Tests deposit flow for all supported collateral types
 */

import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '../frontend/lib/abis';

dotenv.config();

const RPC_URL = process.env.BASE_SEPOLIA_RPC || 'https://sepolia.base.org';
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// Contract addresses
const BTC_VAULT_TOKEN = '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a';
const BTC_VAULT_STRATEGY = '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8';

// Collateral tokens
const COLLATERALS = [
  { symbol: 'WBTC', address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', decimals: 8 },
  { symbol: 'tBTC', address: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802', decimals: 18 }, // Non-standard!
  { symbol: 'sovaBTC', address: '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9', decimals: 8 },
];

async function main() {
  if (!PRIVATE_KEY) {
    console.error('Please set PRIVATE_KEY in .env file');
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  
  console.log('Testing vault interface...');
  console.log('Wallet address:', wallet.address);
  console.log('');

  // Connect to contracts
  const vaultToken = new ethers.Contract(BTC_VAULT_TOKEN, BTC_VAULT_TOKEN_ABI, wallet);
  const vaultStrategy = new ethers.Contract(BTC_VAULT_STRATEGY, BTC_VAULT_STRATEGY_ABI, wallet);

  // Test each collateral
  for (const collateral of COLLATERALS) {
    console.log(`\n=== Testing ${collateral.symbol} ===`);
    
    const token = new ethers.Contract(collateral.address, ERC20_ABI, wallet);
    
    try {
      // 1. Check if collateral is supported
      const isSupported = await vaultStrategy.isSupportedAsset(collateral.address);
      console.log(`✓ Is supported: ${isSupported}`);
      
      if (!isSupported) {
        console.log(`⚠️  ${collateral.symbol} is not supported, skipping...`);
        continue;
      }
      
      // 2. Check balance
      const balance = await token.balanceOf(wallet.address);
      const balanceFormatted = ethers.formatUnits(balance, collateral.decimals);
      console.log(`✓ Balance: ${balanceFormatted} ${collateral.symbol}`);
      
      if (balance === 0n) {
        console.log(`⚠️  No ${collateral.symbol} balance, skipping deposit test...`);
        continue;
      }
      
      // 3. Check current allowance
      const allowance = await token.allowance(wallet.address, BTC_VAULT_TOKEN);
      const allowanceFormatted = ethers.formatUnits(allowance, collateral.decimals);
      console.log(`✓ Current allowance: ${allowanceFormatted} ${collateral.symbol}`);
      
      // 4. Test small deposit amount
      const testAmount = ethers.parseUnits('0.00001', collateral.decimals);
      
      // 5. Preview deposit
      const previewShares = await vaultToken.previewDepositCollateral(collateral.address, testAmount);
      const previewFormatted = ethers.formatUnits(previewShares, 18);
      console.log(`✓ Preview: ${ethers.formatUnits(testAmount, collateral.decimals)} ${collateral.symbol} → ${previewFormatted} vBTC`);
      
      // 6. Check if approval is needed
      if (allowance < testAmount) {
        console.log(`⚠️  Approval needed (current: ${allowanceFormatted}, required: ${ethers.formatUnits(testAmount, collateral.decimals)})`);
        
        // Approve if in test mode
        if (process.argv.includes('--execute')) {
          console.log('  Approving max amount...');
          const approveTx = await token.approve(BTC_VAULT_TOKEN, ethers.MaxUint256);
          await approveTx.wait();
          console.log('  ✓ Approval successful');
        }
      } else {
        console.log(`✓ Sufficient allowance`);
      }
      
      // 7. Test deposit (only if --execute flag is passed)
      if (process.argv.includes('--execute') && allowance >= testAmount) {
        console.log(`  Depositing ${ethers.formatUnits(testAmount, collateral.decimals)} ${collateral.symbol}...`);
        const depositTx = await vaultToken.depositCollateral(
          collateral.address,
          testAmount,
          wallet.address
        );
        const receipt = await depositTx.wait();
        console.log(`  ✓ Deposit successful! Tx: ${receipt.hash}`);
        
        // Check new balance
        const newShares = await vaultToken.balanceOf(wallet.address);
        console.log(`  ✓ New vBTC balance: ${ethers.formatUnits(newShares, 18)}`);
      }
      
    } catch (error: any) {
      console.error(`✗ Error testing ${collateral.symbol}:`, error.message);
    }
  }
  
  console.log('\n=== Vault Stats ===');
  
  // Get vault stats
  const totalAssets = await vaultToken.totalAssets();
  const totalSupply = await vaultToken.totalSupply();
  const userShares = await vaultToken.balanceOf(wallet.address);
  const withdrawalEnabled = await vaultToken.getWithdrawalEnabled();
  
  console.log(`Total Assets: ${ethers.formatUnits(totalAssets, 18)} BTC`);
  console.log(`Total Supply: ${ethers.formatUnits(totalSupply, 18)} vBTC`);
  console.log(`Share Price: ${totalSupply > 0n ? Number(totalAssets) / Number(totalSupply) : 1}`);
  console.log(`Your Shares: ${ethers.formatUnits(userShares, 18)} vBTC`);
  console.log(`Withdrawals Enabled: ${withdrawalEnabled}`);
  
  console.log('\n✓ All tests completed!');
  console.log('\nNote: Run with --execute flag to actually perform deposits');
}

main().catch(error => {
  console.error('Script error:', error);
  process.exit(1);
});