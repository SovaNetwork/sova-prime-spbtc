#!/usr/bin/env npx ts-node

import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

// Token addresses
const TOKENS = [
  { name: 'WBTC', address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', decimals: 8 },
  { name: 'TBTC', address: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802', decimals: 18 },
  { name: 'sovaBTC', address: '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9', decimals: 8 },
];

// ERC20 ABI with potential mint functions
const ERC20_ABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  // Various mint function signatures that might exist
  'function mint(address to, uint256 amount) returns (bool)',
  'function mint(uint256 amount) returns (bool)',
  'function faucet() returns (bool)',
  'function faucet(uint256 amount) returns (bool)',
  'function getMintableBalance() view returns (uint256)',
  'function mintTo(address to, uint256 amount) returns (bool)',
];

async function tryMintTokens() {
  console.log('=== Test Token Minting Script ===\n');
  
  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  const privateKey = process.env.PRIVATE_KEY || '';
  if (!privateKey) {
    console.error('Please set PRIVATE_KEY environment variable');
    console.log('You can create a .env file with: PRIVATE_KEY=your_private_key_here');
    return;
  }
  
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log('Wallet address:', wallet.address);
  
  // Check ETH balance
  const ethBalance = await provider.getBalance(wallet.address);
  console.log('ETH balance:', ethers.formatEther(ethBalance), 'ETH\n');
  
  if (ethBalance === 0n) {
    console.log('⚠️  You need Base Sepolia ETH for gas!');
    console.log('Get test ETH from: https://www.alchemy.com/faucets/base-sepolia');
    return;
  }
  
  // Try to mint each token
  for (const tokenInfo of TOKENS) {
    console.log(`\n=== ${tokenInfo.name} ===`);
    console.log(`Address: ${tokenInfo.address}`);
    
    const token = new ethers.Contract(tokenInfo.address, ERC20_ABI, wallet);
    
    try {
      // Get current balance
      const balance = await token.balanceOf(wallet.address);
      console.log(`Current balance: ${ethers.formatUnits(balance, tokenInfo.decimals)} ${tokenInfo.name}`);
      
      if (balance > 0n) {
        console.log('✅ Already has balance, skipping mint attempt');
        continue;
      }
      
      // Try different mint methods
      const mintAmount = ethers.parseUnits('1', tokenInfo.decimals);
      console.log(`Attempting to mint 1 ${tokenInfo.name}...`);
      
      const mintMethods = [
        { name: 'mint(address,uint256)', fn: () => token.mint(wallet.address, mintAmount) },
        { name: 'mint(uint256)', fn: () => token.mint(mintAmount) },
        { name: 'faucet()', fn: () => token.faucet() },
        { name: 'faucet(uint256)', fn: () => token.faucet(mintAmount) },
        { name: 'mintTo(address,uint256)', fn: () => token.mintTo(wallet.address, mintAmount) },
      ];
      
      let minted = false;
      for (const method of mintMethods) {
        try {
          console.log(`  Trying ${method.name}...`);
          const tx = await method.fn();
          console.log(`  Transaction sent: ${tx.hash}`);
          const receipt = await tx.wait();
          console.log(`  ✅ Success! Gas used: ${receipt.gasUsed.toString()}`);
          
          // Check new balance
          const newBalance = await token.balanceOf(wallet.address);
          console.log(`  New balance: ${ethers.formatUnits(newBalance, tokenInfo.decimals)} ${tokenInfo.name}`);
          minted = true;
          break;
        } catch (error: any) {
          // Silently continue to next method
        }
      }
      
      if (!minted) {
        console.log(`  ❌ No public mint function available for ${tokenInfo.name}`);
        console.log(`  This token may require:`);
        console.log(`    - Special permissions (onlyOwner, etc.)`);
        console.log(`    - A faucet website or bot`);
        console.log(`    - Transfer from another address`);
      }
      
    } catch (error: any) {
      console.log(`  ❌ Error checking ${tokenInfo.name}: ${error.message}`);
    }
  }
  
  console.log('\n=== Summary ===');
  console.log('Check the results above to see which tokens can be minted.');
  console.log('If no tokens can be minted, you may need to:');
  console.log('1. Deploy your own test token contract');
  console.log('2. Get tokens from a faucet or another user');
  console.log('3. Use a different test network with available faucets');
}

tryMintTokens().catch(console.error);