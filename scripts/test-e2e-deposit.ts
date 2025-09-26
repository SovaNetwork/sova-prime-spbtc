#!/usr/bin/env npx ts-node

import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

// Contract addresses
const BTC_VAULT_STRATEGY = '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8';
const BTC_VAULT_TOKEN = '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a';

// Token addresses
const WBTC_ADDRESS = '0xe44b2870eFcd6Bb3C9305808012621f438e9636D'; // 8 decimals
const TBTC_ADDRESS = '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802'; // 18 decimals
const SOVABTC_ADDRESS = '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9'; // 8 decimals

// ABIs
const ERC20_ABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
  // Mint function (if available on test tokens)
  'function mint(address to, uint256 amount) returns (bool)',
  'function mint(uint256 amount) returns (bool)',
];

const VAULT_TOKEN_ABI = [
  'function depositCollateral(address token, uint256 amount, address receiver) returns (uint256)',
  'function previewDepositCollateral(address token, uint256 amount) view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function totalAssets() view returns (uint256)',
];

const STRATEGY_ABI = [
  'function isSupportedAsset(address) view returns (bool)',
  'function getSupportedCollaterals() view returns (address[])',
];

async function testE2EDeposit() {
  console.log('=== E2E Deposit Test on Base Sepolia ===\n');
  
  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
  
  // Get private key from environment or use a test key
  const privateKey = process.env.PRIVATE_KEY || '';
  if (!privateKey) {
    console.error('Please set PRIVATE_KEY environment variable');
    console.log('You can create a .env file with: PRIVATE_KEY=your_private_key_here');
    return;
  }
  
  const wallet = new ethers.Wallet(privateKey, provider);
  console.log('Test wallet address:', wallet.address);
  
  // Get wallet ETH balance
  const ethBalance = await provider.getBalance(wallet.address);
  console.log('ETH balance:', ethers.formatEther(ethBalance), 'ETH');
  
  if (ethBalance === 0n) {
    console.log('\n⚠️  You need Base Sepolia ETH to pay for gas!');
    console.log('Get test ETH from: https://www.alchemy.com/faucets/base-sepolia');
    return;
  }
  
  // Setup contracts
  const wbtcToken = new ethers.Contract(WBTC_ADDRESS, ERC20_ABI, wallet);
  const vaultToken = new ethers.Contract(BTC_VAULT_TOKEN, VAULT_TOKEN_ABI, wallet);
  const strategy = new ethers.Contract(BTC_VAULT_STRATEGY, STRATEGY_ABI, wallet);
  
  console.log('\n=== Step 1: Check Token Balances ===');
  
  const wbtcBalance = await wbtcToken.balanceOf(wallet.address);
  const wbtcDecimals = await wbtcToken.decimals();
  console.log('WBTC balance:', ethers.formatUnits(wbtcBalance, wbtcDecimals), 'WBTC');
  
  const vaultBalance = await vaultToken.balanceOf(wallet.address);
  console.log('Vault shares:', ethers.formatUnits(vaultBalance, 18), 'shares');
  
  console.log('\n=== Step 2: Check Collateral Support ===');
  
  const supportedCollaterals = await strategy.getSupportedCollaterals();
  console.log('Supported collaterals:', supportedCollaterals);
  
  const isWbtcSupported = supportedCollaterals.includes(WBTC_ADDRESS);
  console.log('Is WBTC supported?', isWbtcSupported);
  
  if (!isWbtcSupported) {
    console.log('❌ WBTC is not supported as collateral!');
    return;
  }
  
  console.log('\n=== Step 3: Get Test Tokens ===');
  
  if (wbtcBalance === 0n) {
    console.log('No WBTC balance. Attempting to mint test tokens...');
    
    try {
      // Try to mint tokens (may not work if not available)
      console.log('Attempting to mint 1 WBTC...');
      const mintAmount = ethers.parseUnits('1', wbtcDecimals);
      
      // Try different mint functions
      try {
        const tx = await wbtcToken.mint(wallet.address, mintAmount);
        console.log('Mint tx sent:', tx.hash);
        await tx.wait();
        console.log('✅ Successfully minted 1 WBTC!');
      } catch (e1) {
        try {
          const tx = await wbtcToken.mint(mintAmount);
          console.log('Mint tx sent:', tx.hash);
          await tx.wait();
          console.log('✅ Successfully minted 1 WBTC!');
        } catch (e2) {
          console.log('❌ Cannot mint tokens. The token contract may not have a public mint function.');
          console.log('You may need to:');
          console.log('1. Get tokens from a faucet');
          console.log('2. Ask someone to send you test tokens');
          console.log('3. Deploy your own test token');
          return;
        }
      }
      
      // Check new balance
      const newBalance = await wbtcToken.balanceOf(wallet.address);
      console.log('New WBTC balance:', ethers.formatUnits(newBalance, wbtcDecimals), 'WBTC');
    } catch (error: any) {
      console.error('Error minting:', error.message);
    }
  }
  
  console.log('\n=== Step 4: Approve Vault to Spend Tokens ===');
  
  const depositAmount = ethers.parseUnits('0.01', wbtcDecimals); // 0.01 WBTC
  console.log('Deposit amount:', ethers.formatUnits(depositAmount, wbtcDecimals), 'WBTC');
  
  // Check current allowance
  const currentAllowance = await wbtcToken.allowance(wallet.address, BTC_VAULT_TOKEN);
  console.log('Current allowance:', ethers.formatUnits(currentAllowance, wbtcDecimals), 'WBTC');
  
  if (currentAllowance < depositAmount) {
    console.log('Approving vault to spend tokens...');
    const approveTx = await wbtcToken.approve(BTC_VAULT_TOKEN, depositAmount);
    console.log('Approve tx sent:', approveTx.hash);
    await approveTx.wait();
    console.log('✅ Approval successful!');
  } else {
    console.log('✅ Sufficient allowance already set');
  }
  
  console.log('\n=== Step 5: Preview Deposit ===');
  
  const expectedShares = await vaultToken.previewDepositCollateral(WBTC_ADDRESS, depositAmount);
  console.log('Expected shares:', ethers.formatUnits(expectedShares, 18), 'shares');
  
  console.log('\n=== Step 6: Execute Deposit ===');
  
  console.log('Depositing', ethers.formatUnits(depositAmount, wbtcDecimals), 'WBTC...');
  
  try {
    const depositTx = await vaultToken.depositCollateral(WBTC_ADDRESS, depositAmount, wallet.address);
    console.log('Deposit tx sent:', depositTx.hash);
    console.log('Waiting for confirmation...');
    
    const receipt = await depositTx.wait();
    console.log('✅ Deposit successful!');
    console.log('Transaction hash:', receipt.hash);
    console.log('Block number:', receipt.blockNumber);
    console.log('Gas used:', receipt.gasUsed.toString());
    
    // Check for events
    console.log('\n=== Events Emitted ===');
    receipt.logs.forEach((log: any, index: number) => {
      console.log(`Event ${index}:`, log);
    });
    
  } catch (error: any) {
    console.error('❌ Deposit failed:', error.message);
    return;
  }
  
  console.log('\n=== Step 7: Verify Final Balances ===');
  
  const finalWbtcBalance = await wbtcToken.balanceOf(wallet.address);
  const finalVaultBalance = await vaultToken.balanceOf(wallet.address);
  const totalSupply = await vaultToken.totalSupply();
  const totalAssets = await vaultToken.totalAssets();
  
  console.log('Final WBTC balance:', ethers.formatUnits(finalWbtcBalance, wbtcDecimals), 'WBTC');
  console.log('Final vault shares:', ethers.formatUnits(finalVaultBalance, 18), 'shares');
  console.log('Vault total supply:', ethers.formatUnits(totalSupply, 18), 'shares');
  console.log('Vault total assets:', ethers.formatUnits(totalAssets, 8), 'BTC value');
  
  console.log('\n=== Step 8: Check Indexer ===');
  
  console.log('Checking if Ponder indexer captured the event...');
  console.log('GraphQL endpoint: https://ponder-indexer-production.up.railway.app/graphql');
  
  // Query the indexer (you can do this manually or via curl)
  const query = `
    query {
      btcDepositss(orderBy: "blockTimestamp", orderDirection: "desc", limit: 1) {
        items {
          id
          sender
          owner
          assets
          shares
          blockTimestamp
          transactionHash
        }
      }
    }
  `;
  
  console.log('\nYou can query the indexer with:');
  console.log(`curl -X POST https://ponder-indexer-production.up.railway.app/graphql \\`);
  console.log(`  -H "Content-Type: application/json" \\`);
  console.log(`  -d '{"query":"${query.replace(/\n/g, ' ').replace(/\s+/g, ' ')}"}'`);
  
  console.log('\n✅ E2E Deposit Test Complete!');
  console.log('Check the frontend at http://localhost:3000 to see if the transaction appears.');
}

testE2EDeposit().catch(console.error);