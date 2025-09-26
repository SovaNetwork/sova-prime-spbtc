#!/usr/bin/env npx ts-node

import { ethers } from 'ethers';

// Contract addresses
const BTC_VAULT_STRATEGY = '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8';
const BTC_VAULT_TOKEN = '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a';

// Potential test token addresses from contracts.ts
const WBTC_ADDRESS = '0xe44b2870eFcd6Bb3C9305808012621f438e9636D';
const TBTC_ADDRESS = '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802';
const SOVABTC_ADDRESS = '0xe44b2870eFcd6Bb3C9305808012621f438e9636D';

// Strategy ABI - only functions we need
const STRATEGY_ABI = [
  'function isSupportedCollateral(address) view returns (bool)',
  'function supportedAssets(address) view returns (bool)',
  'function collateralTokens(uint256) view returns (address)',
  'function asset() view returns (address)',
  'function getSupportedCollaterals() view returns (address[])',
];

// ERC20 ABI for token info
const ERC20_ABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
];

async function checkCollateralSupport() {
  // Connect to Base Sepolia
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  // Create contract instances
  const strategy = new ethers.Contract(BTC_VAULT_STRATEGY, STRATEGY_ABI, provider);
  
  console.log('=== BTC Vault Strategy Collateral Check ===\n');
  console.log('Strategy Address:', BTC_VAULT_STRATEGY);
  console.log('Token Address:', BTC_VAULT_TOKEN);
  console.log('\n=== Checking Asset (sovaBTC) ===');
  
  try {
    const assetAddress = await strategy.asset();
    console.log('Asset address from strategy:', assetAddress);
    
    const assetToken = new ethers.Contract(assetAddress, ERC20_ABI, provider);
    const assetName = await assetToken.name();
    const assetSymbol = await assetToken.symbol();
    const assetDecimals = await assetToken.decimals();
    console.log(`Asset info: ${assetName} (${assetSymbol}), decimals: ${assetDecimals}`);
  } catch (error: any) {
    console.error('Error getting asset info:', error.message);
  }
  
  console.log('\n=== Checking Token Support ===');
  
  // Check WBTC
  console.log('\n1. WBTC (address:', WBTC_ADDRESS, ')');
  try {
    const isSupported = await strategy.isSupportedCollateral(WBTC_ADDRESS);
    console.log('   Is supported:', isSupported);
    
    if (WBTC_ADDRESS.toLowerCase() !== '0x0000000000000000000000000000000000000000') {
      const token = new ethers.Contract(WBTC_ADDRESS, ERC20_ABI, provider);
      try {
        const name = await token.name();
        const symbol = await token.symbol();
        const decimals = await token.decimals();
        console.log(`   Token info: ${name} (${symbol}), decimals: ${decimals}`);
      } catch (e) {
        console.log('   Token does not exist at this address');
      }
    }
  } catch (error: any) {
    console.error('   Error:', error.message);
  }
  
  // Check TBTC
  console.log('\n2. TBTC (address:', TBTC_ADDRESS, ')');
  try {
    const isSupported = await strategy.isSupportedCollateral(TBTC_ADDRESS);
    console.log('   Is supported:', isSupported);
    
    const token = new ethers.Contract(TBTC_ADDRESS, ERC20_ABI, provider);
    try {
      const name = await token.name();
      const symbol = await token.symbol();
      const decimals = await token.decimals();
      console.log(`   Token info: ${name} (${symbol}), decimals: ${decimals}`);
    } catch (e) {
      console.log('   Token does not exist at this address');
    }
  } catch (error: any) {
    console.error('   Error:', error.message);
  }
  
  // Check sovaBTC
  console.log('\n3. sovaBTC (address:', SOVABTC_ADDRESS, ')');
  try {
    const isSupported = await strategy.isSupportedCollateral(SOVABTC_ADDRESS);
    console.log('   Is supported:', isSupported);
    
    const token = new ethers.Contract(SOVABTC_ADDRESS, ERC20_ABI, provider);
    try {
      const name = await token.name();
      const symbol = await token.symbol();
      const decimals = await token.decimals();
      console.log(`   Token info: ${name} (${symbol}), decimals: ${decimals}`);
    } catch (e) {
      console.log('   Token does not exist at this address');
    }
  } catch (error: any) {
    console.error('   Error:', error.message);
  }
  
  console.log('\n=== Getting All Supported Collaterals ===');
  try {
    // Try to get supported collaterals - this function might not exist
    const supportedCollaterals = await strategy.getSupportedCollaterals();
    console.log('Supported collaterals:', supportedCollaterals);
  } catch (error) {
    console.log('getSupportedCollaterals() not available, trying alternative method...');
    
    // Try to enumerate through collateralTokens array
    try {
      let i = 0;
      const collaterals = [];
      while (true) {
        try {
          const tokenAddress = await strategy.collateralTokens(i);
          collaterals.push(tokenAddress);
          
          const token = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
          try {
            const name = await token.name();
            const symbol = await token.symbol();
            const decimals = await token.decimals();
            console.log(`   [${i}] ${tokenAddress}: ${name} (${symbol}), decimals: ${decimals}`);
          } catch (e) {
            console.log(`   [${i}] ${tokenAddress}: Unable to get token info`);
          }
          
          i++;
        } catch (e) {
          // Array index out of bounds, we've enumerated all
          break;
        }
      }
      console.log(`Total supported collaterals: ${collaterals.length}`);
      console.log('Collateral addresses:', collaterals);
    } catch (error: any) {
      console.error('Error enumerating collaterals:', error.message);
    }
  }
  
  console.log('\n=== Strategy Balance Check ===');
  try {
    const assetAddress = await strategy.asset();
    const assetToken = new ethers.Contract(assetAddress, ERC20_ABI, provider);
    const strategyBalance = await assetToken.balanceOf(BTC_VAULT_STRATEGY);
    console.log('Strategy sovaBTC balance:', ethers.formatUnits(strategyBalance, 8), 'sovaBTC');
  } catch (error: any) {
    console.error('Error checking balance:', error.message);
  }
}

checkCollateralSupport().catch(console.error);