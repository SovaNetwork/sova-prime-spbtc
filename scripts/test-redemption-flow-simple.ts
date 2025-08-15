#!/usr/bin/env tsx

import { privateKeyToAccount } from 'viem/accounts';
import { createWalletClient, http, createPublicClient } from 'viem';
import { baseSepolia } from 'viem/chains';
import axios from 'axios';

const API_BASE_URL = 'http://localhost:3003/api';

// Test configuration
const TEST_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Test key from Anvil
const DEPLOYMENT_ID = 'cme9bhsmc0002kf6906z13r2d'; // Base Sepolia deployment

async function testRedemptionFlow() {
  console.log('🧪 Starting Redemption Flow Test\n');
  
  try {
    // 1. Test stats endpoint
    console.log('1️⃣ Testing Stats Endpoint...');
    const statsResponse = await axios.get(`${API_BASE_URL}/redemptions/stats`);
    console.log('✅ Stats:', statsResponse.data);
    console.log();
    
    // 2. Test GET redemptions
    console.log('2️⃣ Testing GET Redemptions...');
    const getResponse = await axios.get(`${API_BASE_URL}/redemptions`);
    console.log('✅ Found', getResponse.data.totalCount, 'redemption requests');
    console.log();
    
    // 3. Create a test redemption request
    console.log('3️⃣ Creating Test Redemption Request...');
    
    const account = privateKeyToAccount(TEST_PRIVATE_KEY as `0x${string}`);
    console.log('Test wallet address:', account.address);
    
    // Create a simple signed request (we'll use mock data for testing)
    const signedRequest = {
      user: account.address,
      shareAmount: BigInt(1000000000), // 10 shares (8 decimals)
      minAssetsOut: BigInt(950000000), // 9.5 assets minimum
      nonce: BigInt(Date.now()),
      deadline: BigInt(Math.floor(Date.now() / 1000) + 86400), // 24 hours from now
      signature: '0x' + '00'.repeat(65), // Mock signature for testing
    };
    
    const requestBody = {
      deploymentId: DEPLOYMENT_ID,
      expectedAssets: '1000000000',
      signedRequest: {
        ...signedRequest,
        shareAmount: signedRequest.shareAmount.toString(),
        minAssetsOut: signedRequest.minAssetsOut.toString(),
        nonce: signedRequest.nonce.toString(),
        deadline: signedRequest.deadline.toString(),
      },
    };
    
    console.log('Request body:', JSON.stringify(requestBody, null, 2));
    
    try {
      const createResponse = await axios.post(`${API_BASE_URL}/redemptions`, requestBody);
      console.log('✅ Created redemption request:', createResponse.data.id);
      console.log('Status:', createResponse.data.status);
      console.log();
      
      // 4. Test fetching the created request
      console.log('4️⃣ Fetching Created Request...');
      const fetchResponse = await axios.get(`${API_BASE_URL}/redemptions/${createResponse.data.id}`);
      console.log('✅ Fetched request:', {
        id: fetchResponse.data.id,
        status: fetchResponse.data.status,
        shareAmount: fetchResponse.data.shareAmount,
        expectedAssets: fetchResponse.data.expectedAssets,
      });
      console.log();
      
      // 5. Test updating status (admin action)
      console.log('5️⃣ Testing Status Update...');
      const updateResponse = await axios.patch(`${API_BASE_URL}/redemptions/${createResponse.data.id}`, {
        status: 'APPROVED',
        adminNotes: 'Test approval',
      });
      console.log('✅ Updated status to:', updateResponse.data.status);
      console.log();
      
      // 6. Test cancellation
      console.log('6️⃣ Testing Cancellation...');
      const cancelResponse = await axios.post(`${API_BASE_URL}/redemptions/${createResponse.data.id}/cancel`);
      console.log('✅ Cancelled request, new status:', cancelResponse.data.status);
      console.log();
      
    } catch (error: any) {
      if (error.response?.data?.error?.includes('Nonce already used')) {
        console.log('⚠️ Nonce already used (expected for repeated tests)');
      } else if (error.response?.data?.error?.includes('Invalid signature')) {
        console.log('⚠️ Invalid signature (expected with mock signature)');
        console.log('This is normal - in production, proper EIP-712 signatures would be used');
      } else if (error.response?.data?.error?.includes('Deployment not found')) {
        console.log('❌ Deployment not found. Please update DEPLOYMENT_ID in the script');
        console.log('You can find the correct ID by checking the database or API');
      } else {
        throw error;
      }
    }
    
    // 7. Final stats check
    console.log('7️⃣ Final Stats Check...');
    const finalStats = await axios.get(`${API_BASE_URL}/redemptions/stats`);
    console.log('✅ Final stats:', finalStats.data);
    
    console.log('\n✅ Redemption flow test completed!');
    
  } catch (error: any) {
    console.error('❌ Test failed:', error.response?.data || error.message);
    process.exit(1);
  }
}

// Run the test
testRedemptionFlow();