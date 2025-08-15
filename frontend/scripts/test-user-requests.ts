import { RedemptionAPI } from '../lib/redemption-api';

async function testUserRequests() {
  console.log('Testing user redemption requests API...\n');

  // Initialize with full URL for Node.js environment
  const redemptionAPI = new RedemptionAPI('http://localhost:3000/api');
  
  const userAddress = '0x1F53AA5D3B5743bD0D41884124bC07F4D7682fc1';
  const deploymentId = 'cme9bhsmc0002kf6906z13r2d';

  try {
    console.log('Testing getUserRequests method...');
    console.log('User address:', userAddress);
    console.log('Deployment ID:', deploymentId);
    
    const requests = await redemptionAPI.getUserRequests(userAddress, deploymentId);
    
    console.log('\n✅ Successfully fetched user requests:');
    console.log('Number of requests:', requests.length);
    
    if (requests.length > 0) {
      console.log('\nFirst request:');
      console.log(JSON.stringify(requests[0], null, 2));
    }
  } catch (error) {
    console.error('❌ Failed to fetch user requests:', error);
  }

  // Also test the general getRedemptionRequests method
  try {
    console.log('\n\nTesting getRedemptionRequests with filters...');
    
    const result = await redemptionAPI.getRedemptionRequests({
      userAddress,
      deploymentId,
    });
    
    console.log('✅ Successfully fetched with getRedemptionRequests:');
    console.log('Total count:', result.totalCount);
    console.log('Number of requests:', result.requests.length);
  } catch (error) {
    console.error('❌ Failed with getRedemptionRequests:', error);
  }
}

testUserRequests().catch(console.error);