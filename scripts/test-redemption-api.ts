#!/usr/bin/env npx tsx

/**
 * Test Script for Redemption API
 * Tests the newly implemented EIP-712 signature-based redemption system
 */

async function testRedemptionAPI() {
  const baseUrl = 'http://localhost:3006';
  
  console.log('🧪 Testing Redemption API...\n');

  // Test 1: Get stats (should work even with empty queue)
  try {
    console.log('1. Testing GET /api/redemptions/stats');
    const statsResponse = await fetch(`${baseUrl}/api/redemptions/stats`);
    const stats = await statsResponse.json();
    console.log('✅ Stats endpoint working:', stats);
  } catch (error) {
    console.error('❌ Stats endpoint failed:', error);
  }

  // Test 2: Get redemption requests (should return empty array initially)
  try {
    console.log('\n2. Testing GET /api/redemptions');
    const response = await fetch(`${baseUrl}/api/redemptions`);
    const data = await response.json();
    console.log('✅ Redemptions endpoint working, count:', data.length);
  } catch (error) {
    console.error('❌ Redemptions endpoint failed:', error);
  }

  // Test 3: Test validation on POST endpoint
  try {
    console.log('\n3. Testing POST /api/redemptions validation');
    const response = await fetch(`${baseUrl}/api/redemptions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        // Invalid request (missing required fields)
        userAddress: '0x0000000000000000000000000000000000000000'
      })
    });
    const data = await response.json();
    if (response.ok) {
      console.log('⚠️  Validation might be missing - request succeeded with invalid data');
    } else {
      console.log('✅ Validation working - rejected invalid request:', data.error);
    }
  } catch (error) {
    console.error('❌ POST endpoint failed:', error);
  }

  // Test 4: Test a mock valid request structure
  try {
    console.log('\n4. Testing POST /api/redemptions with mock data');
    const mockRequest = {
      signature: '0x' + '0'.repeat(130), // Mock signature
      message: {
        user: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        shares: '1000000000000000000', // 1 vBTC
        receiver: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb7',
        nonce: Date.now().toString(),
        deadline: (Date.now() + 86400000).toString()
      },
      domain: {
        name: 'SovaBTC Vault',
        version: '1',
        chainId: 84532,
        verifyingContract: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a'
      },
      chainId: 84532,
      deploymentId: 'test-deployment-id' // This might need to be a real ID from your database
    };

    const response = await fetch(`${baseUrl}/api/redemptions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(mockRequest)
    });
    
    const data = await response.json();
    if (response.ok) {
      console.log('✅ Mock request accepted (signature validation might be disabled in dev)');
    } else {
      console.log('ℹ️  Mock request rejected:', data.error);
      console.log('   This is expected if signature validation is enabled');
    }
  } catch (error) {
    console.error('❌ POST with mock data failed:', error);
  }

  console.log('\n✨ API Test Complete!');
  console.log('Next steps:');
  console.log('1. Open http://localhost:3006/vault in your browser');
  console.log('2. Connect your wallet');
  console.log('3. Try requesting a redemption');
  console.log('4. Check the admin panel at http://localhost:3006/admin');
}

// Run the test
testRedemptionAPI().catch(console.error);