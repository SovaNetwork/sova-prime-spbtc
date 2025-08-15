import { serializeBigInt } from '../lib/utils';

// Test the BigInt handling for redemption requests
async function testRedemptionBigInt() {
  console.log('Testing BigInt handling in redemption API...\n');

  // Simulate the signed request that comes from the frontend
  const signedRequest = {
    user: '0x1F53AA5D3B5743bD0D41884124bC07F4D7682fc1',
    shareAmount: '10000000000000000000', // 10 shares with 18 decimals
    minAssetsOut: '995000000', // 9.95 BTC with 8 decimals
    nonce: '1755266858695',
    deadline: '1755266858', // Unix timestamp
    signature: '0xd9e4f33d07d73602e69dd701aa244539bfe030006eeb7f3fc713620a292d5f2331b61460e027abf002f596612815bd19149a699f49366b3ba7a06fb2e46a51111c'
  };

  // Test BigInt conversions
  console.log('Testing BigInt conversions:');
  console.log('shareAmount string:', signedRequest.shareAmount);
  console.log('shareAmount BigInt:', BigInt(signedRequest.shareAmount));
  console.log('minAssetsOut string:', signedRequest.minAssetsOut);
  console.log('minAssetsOut BigInt:', BigInt(signedRequest.minAssetsOut));
  console.log('nonce string:', signedRequest.nonce);
  console.log('nonce BigInt:', BigInt(signedRequest.nonce));
  console.log();

  // Test serialization
  const requestBody = {
    deploymentId: 'cme9bhsmc0002kf6906z13r2d',
    expectedAssets: '10',
    signedRequest: serializeBigInt(signedRequest)
  };

  console.log('Serialized request body:');
  console.log(JSON.stringify(requestBody, null, 2));
  console.log();

  // Test API call
  console.log('Testing API endpoint...');
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
  
  try {
    const response = await fetch(`${baseUrl}/api/redemptions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('API Error:', response.status, errorText);
    } else {
      const data = await response.json();
      console.log('✅ API Response:', data);
    }
  } catch (error) {
    console.error('❌ Request failed:', error);
  }
}

// Run the test
testRedemptionBigInt().catch(console.error);