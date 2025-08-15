#!/usr/bin/env npx ts-node

import { ethers } from 'ethers';

// Token addresses from our findings
const TOKENS = [
  { address: '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9', label: 'sovaBTC (main asset)' },
  { address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', label: 'Test Token 1' },
  { address: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802', label: 'Test Token 2' },
];

// ERC20 ABI for token info
const ERC20_ABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
];

async function checkTokenInfo() {
  // Connect to Base Sepolia
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  console.log('=== Base Sepolia BTC Token Information ===\n');
  
  for (const tokenInfo of TOKENS) {
    console.log(`\n${tokenInfo.label}:`);
    console.log(`Address: ${tokenInfo.address}`);
    
    try {
      const token = new ethers.Contract(tokenInfo.address, ERC20_ABI, provider);
      
      const name = await token.name();
      const symbol = await token.symbol();
      const decimals = await token.decimals();
      const totalSupply = await token.totalSupply();
      
      console.log(`  Name: ${name}`);
      console.log(`  Symbol: ${symbol}`);
      console.log(`  Decimals: ${decimals}`);
      console.log(`  Total Supply: ${ethers.formatUnits(totalSupply, decimals)}`);
      
      // Check test wallet balance
      const testWallet = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'; // Common test wallet
      const balance = await token.balanceOf(testWallet);
      console.log(`  Test Wallet Balance: ${ethers.formatUnits(balance, decimals)}`);
      
    } catch (error: any) {
      console.log(`  ERROR: Token does not exist or is not ERC20 compliant`);
      console.log(`  Details: ${error.message}`);
    }
  }
  
  console.log('\n=== Summary ===');
  console.log('These are the tokens supported by the BTC Vault on Base Sepolia.');
  console.log('All tokens should have 8 decimals (BTC standard).');
}

checkTokenInfo().catch(console.error);