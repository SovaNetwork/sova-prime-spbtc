#!/usr/bin/env npx ts-node

import { ethers } from 'ethers';

// Contract addresses
const BTC_VAULT_STRATEGY = '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8';

// Token addresses  
const WBTC_ADDRESS = '0xe44b2870eFcd6Bb3C9305808012621f438e9636D';
const TBTC_ADDRESS = '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802';

// Strategy ABI
const STRATEGY_ABI = [
  'function isSupportedAsset(address) view returns (bool)',
  'function supportedAssets(address) view returns (bool)', 
  'function collateralTokens(uint256) view returns (address)',
  'function getSupportedCollaterals() view returns (address[])',
  'function addCollateral(address token, uint8 decimals) external',
  'function removeCollateral(address token) external',
  'function manager() view returns (address)',
  'function roleManager() view returns (address)',
];

async function fixCollateralSupport() {
  console.log('=== Fixing Collateral Support ===\n');
  
  // Connect to Base Sepolia
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  // Setup wallet if we need to make transactions
  const privateKey = process.env.PRIVATE_KEY || '';
  let wallet: ethers.Wallet | null = null;
  
  if (privateKey) {
    wallet = new ethers.Wallet(privateKey, provider);
    console.log('Connected wallet:', wallet.address);
  }
  
  // Create contract instance
  const strategy = new ethers.Contract(BTC_VAULT_STRATEGY, STRATEGY_ABI, provider);
  
  console.log('Strategy Address:', BTC_VAULT_STRATEGY);
  
  // Get manager address
  try {
    const manager = await strategy.manager();
    console.log('Manager address:', manager);
    
    if (wallet && wallet.address.toLowerCase() === manager.toLowerCase()) {
      console.log('✅ Your wallet is the manager!');
    } else if (wallet) {
      console.log('⚠️  Your wallet is NOT the manager. You cannot add/remove collaterals.');
    }
  } catch (e) {
    console.log('Could not get manager address');
  }
  
  console.log('\n=== Current State ===');
  
  // Get list from getSupportedCollaterals
  const collateralList = await strategy.getSupportedCollaterals();
  console.log('Collaterals from getSupportedCollaterals():', collateralList);
  
  // Check each token's supportedAssets mapping
  console.log('\n=== Checking supportedAssets Mapping ===');
  for (const token of collateralList) {
    try {
      // Try direct mapping access
      const isSupported = await strategy.supportedAssets(token);
      console.log(`${token}: ${isSupported}`);
    } catch (e) {
      console.log(`${token}: Error checking mapping`);
    }
  }
  
  console.log('\n=== Checking WBTC Specifically ===');
  console.log('WBTC address:', WBTC_ADDRESS);
  console.log('Is WBTC in collateral list?', collateralList.map((a: string) => a.toLowerCase()).includes(WBTC_ADDRESS.toLowerCase()));
  
  try {
    const wbtcSupported = await strategy.supportedAssets(WBTC_ADDRESS);
    console.log('WBTC supportedAssets mapping:', wbtcSupported);
  } catch (e) {
    console.log('Error checking WBTC mapping:', e);
  }
  
  // If we have a wallet and it's the manager, offer to fix
  if (wallet && privateKey) {
    const manager = await strategy.manager();
    if (wallet.address.toLowerCase() === manager.toLowerCase()) {
      console.log('\n=== Fix Options ===');
      console.log('As the manager, you can:');
      console.log('1. Re-add WBTC as collateral to fix the mapping');
      console.log('2. Remove and re-add to ensure clean state');
      
      // Check if WBTC needs fixing
      const wbtcInList = collateralList.map((a: string) => a.toLowerCase()).includes(WBTC_ADDRESS.toLowerCase());
      const wbtcSupported = await strategy.supportedAssets(WBTC_ADDRESS).catch(() => false);
      
      if (wbtcInList && !wbtcSupported) {
        console.log('\n⚠️  WBTC is in the list but supportedAssets is false!');
        console.log('This needs to be fixed.');
        
        console.log('\nTo fix, run these commands:');
        console.log('\n# Remove WBTC first (to clean state)');
        console.log(`cast send ${BTC_VAULT_STRATEGY} "removeCollateral(address)" ${WBTC_ADDRESS} --private-key $PRIVATE_KEY --rpc-url base-sepolia`);
        
        console.log('\n# Then add it back with correct decimals');
        console.log(`cast send ${BTC_VAULT_STRATEGY} "addCollateral(address,uint8)" ${WBTC_ADDRESS} 8 --private-key $PRIVATE_KEY --rpc-url base-sepolia`);
      } else if (!wbtcInList) {
        console.log('\n⚠️  WBTC is not in the collateral list at all!');
        console.log('\nTo add WBTC:');
        console.log(`cast send ${BTC_VAULT_STRATEGY} "addCollateral(address,uint8)" ${WBTC_ADDRESS} 8 --private-key $PRIVATE_KEY --rpc-url base-sepolia`);
      } else if (wbtcSupported) {
        console.log('\n✅ WBTC appears to be properly configured!');
      }
    }
  }
  
  console.log('\n=== Alternative Solution ===');
  console.log('If you cannot fix the contract state, you can:');
  console.log('1. Use sovaBTC for testing (it should work)');
  console.log('2. Deploy a new MockBTC token and add it as collateral');
  console.log('3. Update the frontend to use a different check method');
  
  console.log('\n=== Frontend Workaround ===');
  console.log('The frontend could check getSupportedCollaterals() instead of isSupportedAsset()');
  console.log('This would bypass the broken mapping issue.');
}

fixCollateralSupport().catch(console.error);