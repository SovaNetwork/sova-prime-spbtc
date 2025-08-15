#!/usr/bin/env node

/**
 * Test the redemption API endpoints
 */

async function testRedemptionAPI() {
  const baseUrl = 'http://localhost:3000'
  const deploymentId = 'cme9bhsmc0002kf6906z13r2d' // From database
  
  console.log('🔍 Testing Redemption API Endpoints\n')
  
  try {
    // Test 1: Get redemption requests
    console.log('1. Testing GET /api/redemptions')
    const requestsResponse = await fetch(`${baseUrl}/api/redemptions?deploymentId=${deploymentId}`)
    if (requestsResponse.ok) {
      const data = await requestsResponse.json()
      console.log(`   ✅ Success: Found ${data.requests?.length || 0} requests`)
      if (data.requests?.length > 0) {
        console.log(`   First request status: ${data.requests[0].status}`)
      }
    } else {
      console.log(`   ❌ Failed: ${requestsResponse.status} ${requestsResponse.statusText}`)
    }
    
    // Test 2: Get queue stats
    console.log('\n2. Testing GET /api/redemptions/stats')
    const statsResponse = await fetch(`${baseUrl}/api/redemptions/stats?deploymentId=${deploymentId}`)
    if (statsResponse.ok) {
      const stats = await statsResponse.json()
      console.log(`   ✅ Success: Queue stats retrieved`)
      console.log(`   Total requests: ${stats.totalRequests}`)
      console.log(`   Pending: ${stats.pendingRequests}`)
    } else {
      console.log(`   ❌ Failed: ${statsResponse.status} ${statsResponse.statusText}`)
    }
    
    // Test 3: Check liquidity
    console.log('\n3. Testing GET /api/admin/redemptions/liquidity')
    const liquidityUrl = `${baseUrl}/api/admin/redemptions/liquidity?strategyAddress=0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8&tokenAddress=0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a`
    const liquidityResponse = await fetch(liquidityUrl)
    if (liquidityResponse.ok) {
      const liquidity = await liquidityResponse.json()
      console.log(`   ✅ Success: Liquidity data retrieved`)
      console.log(`   Available: ${liquidity.availableLiquidity}`)
      console.log(`   Can process: ${liquidity.canProcessRedemptions}`)
    } else {
      console.log(`   ❌ Failed: ${liquidityResponse.status} ${liquidityResponse.statusText}`)
    }
    
    // Test 4: Get pending requests (admin)
    console.log('\n4. Testing GET /api/admin/redemptions/pending')
    const pendingResponse = await fetch(`${baseUrl}/api/admin/redemptions/pending?deploymentId=${deploymentId}&includeApproved=true`)
    if (pendingResponse.ok) {
      const pending = await pendingResponse.json()
      console.log(`   ✅ Success: Admin endpoint working`)
      console.log(`   Pending count: ${pending.totals?.pendingCount || 0}`)
      console.log(`   Approved count: ${pending.totals?.approvedCount || 0}`)
    } else {
      console.log(`   ❌ Failed: ${pendingResponse.status} ${pendingResponse.statusText}`)
    }
    
    console.log('\n✅ API test complete!')
    
  } catch (error) {
    console.error('Error testing API:', error)
  }
}

testRedemptionAPI().catch(console.error)