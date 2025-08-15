/**
 * Test script for collateral management API endpoints
 */

const API_BASE = 'http://localhost:3005/api';

async function testCollateralAPIs() {
  console.log('Testing Collateral Management APIs...\n');

  try {
    // 1. Test fetching collaterals
    console.log('1. Testing GET /api/collaterals');
    const collateralsResponse = await fetch(`${API_BASE}/collaterals?chainId=84532`);
    const collaterals = await collateralsResponse.json();
    console.log(`   ✅ Found ${collaterals.length} collaterals`);
    collaterals.forEach((c: any) => {
      console.log(`      - ${c.symbol}: ${c.address} (${c.isActive ? 'Active' : 'Inactive'})`);
    });

    // 2. Test token registry
    console.log('\n2. Testing GET /api/token-registry');
    const registryResponse = await fetch(`${API_BASE}/token-registry?category=btc`);
    const registry = await registryResponse.json();
    console.log(`   ✅ Found ${registry.length} tokens in registry`);
    registry.forEach((t: any) => {
      const networks = Object.keys(t.addresses || {}).length;
      console.log(`      - ${t.symbol}: ${networks} networks configured`);
    });

    // 3. Test adding a new collateral
    console.log('\n3. Testing POST /api/collaterals (adding test token)');
    const testToken = {
      deploymentId: collaterals[0]?.deploymentId || 'test-deployment',
      symbol: 'TEST-BTC',
      name: 'Test Bitcoin Token',
      address: '0x' + Math.random().toString(16).substring(2, 42).padEnd(40, '0'),
      chainId: 84532,
      decimals: 18,
      logoUri: 'https://example.com/test.png',
      coingeckoId: 'test-btc',
    };

    const addResponse = await fetch(`${API_BASE}/collaterals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(testToken),
    });

    if (addResponse.ok) {
      const newCollateral = await addResponse.json();
      console.log(`   ✅ Added new collateral: ${newCollateral.symbol} (ID: ${newCollateral.id})`);

      // 4. Test updating the collateral
      console.log('\n4. Testing PUT /api/collaterals/:id');
      const updateResponse = await fetch(`${API_BASE}/collaterals/${newCollateral.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          isActive: false,
          isVerified: true,
        }),
      });

      if (updateResponse.ok) {
        console.log('   ✅ Updated collateral status');
      } else {
        console.log('   ❌ Failed to update collateral');
      }

      // 5. Test deleting (deactivating) the collateral
      console.log('\n5. Testing DELETE /api/collaterals/:id');
      const deleteResponse = await fetch(`${API_BASE}/collaterals/${newCollateral.id}`, {
        method: 'DELETE',
      });

      if (deleteResponse.ok) {
        console.log('   ✅ Deactivated collateral');
      } else {
        console.log('   ❌ Failed to deactivate collateral');
      }
    } else {
      const error = await addResponse.json();
      console.log(`   ❌ Failed to add collateral: ${error.error}`);
    }

    // 6. Test sync endpoint (will fail without proper RPC but tests the endpoint)
    console.log('\n6. Testing POST /api/collaterals/sync');
    const syncResponse = await fetch(`${API_BASE}/collaterals/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deploymentId: collaterals[0]?.deploymentId || 'test-deployment',
        chainId: 84532,
      }),
    });

    if (syncResponse.ok) {
      const syncResult = await syncResponse.json();
      console.log(`   ✅ Sync attempted: ${syncResult.message || 'Success'}`);
    } else {
      const error = await syncResponse.json();
      console.log(`   ⚠️  Sync failed (expected without RPC): ${error.error}`);
    }

    console.log('\n✅ All API tests completed!');
    console.log('\nYou can now:');
    console.log('1. Visit http://localhost:3005/vault to test the deposit form with dynamic collaterals');
    console.log('2. Visit http://localhost:3005/admin to test the admin panel with collateral sync');
    console.log('3. The collaterals will be loaded dynamically based on the connected network');

  } catch (error) {
    console.error('Test failed:', error);
  }
}

// Run the tests
testCollateralAPIs();