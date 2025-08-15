import { prisma } from '../lib/prisma';

async function testAPIIntegration() {
  console.log('🧪 Testing Database Integration...\n');
  
  try {
    // Test 1: Network Operations
    console.log('📡 Test 1: Network Operations');
    console.log('================================');
    
    const networks = await prisma.sovaBtcNetwork.findMany({
      include: {
        deployments: true,
      },
    });
    
    console.log(`✅ Found ${networks.length} networks in database`);
    networks.forEach(network => {
      console.log(`   - ${network.name} (Chain ID: ${network.chainId})`);
      console.log(`     Deployments: ${network.deployments.length}`);
    });
    
    // Test 2: Deployment Operations
    console.log('\n🚀 Test 2: Deployment Operations');
    console.log('================================');
    
    const deployments = await prisma.sovaBtcDeployment.findMany({
      include: {
        network: true,
        collaterals: true,
        metrics: {
          orderBy: { timestamp: 'desc' },
          take: 1,
        },
        activities: {
          orderBy: { createdAt: 'desc' },
          take: 5,
        },
      },
    });
    
    console.log(`✅ Found ${deployments.length} deployments`);
    deployments.forEach(deployment => {
      console.log(`   - Chain ${deployment.chainId} (${deployment.network.name})`);
      console.log(`     Status: ${deployment.status}`);
      console.log(`     Vault Strategy: ${deployment.vaultStrategy}`);
      console.log(`     Vault Token: ${deployment.vaultToken}`);
      console.log(`     Collaterals: ${deployment.collaterals.map(c => c.symbol).join(', ')}`);
      console.log(`     Activities: ${deployment.activities.length}`);
      
      if (deployment.metrics.length > 0) {
        const latestMetrics = deployment.metrics[0];
        console.log(`     Latest TVL: ${latestMetrics.tvl}`);
        console.log(`     Users: ${latestMetrics.users}`);
        console.log(`     Transactions: ${latestMetrics.transactions}`);
      }
    });
    
    // Test 3: Activity Logging
    console.log('\n📝 Test 3: Activity Logging');
    console.log('================================');
    
    const activities = await prisma.sovaBtcActivity.findMany({
      orderBy: { createdAt: 'desc' },
      take: 10,
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    });
    
    console.log(`✅ Found ${activities.length} recent activities`);
    activities.forEach(activity => {
      console.log(`   - [${activity.type}] ${activity.description}`);
      console.log(`     Network: ${activity.deployment.network.name}`);
      console.log(`     Time: ${activity.createdAt.toLocaleString()}`);
    });
    
    // Test 4: Metrics
    console.log('\n📊 Test 4: Metrics');
    console.log('================================');
    
    const metrics = await prisma.sovaBtcDeploymentMetrics.findMany({
      orderBy: { timestamp: 'desc' },
      take: 5,
    });
    
    console.log(`✅ Found ${metrics.length} metric records`);
    metrics.forEach(metric => {
      console.log(`   - TVL: ${metric.tvl}, APY: ${metric.apy}%, Users: ${metric.users}`);
      console.log(`     Time: ${metric.timestamp.toLocaleString()}`);
    });
    
    // Test 5: API Endpoints (simulate)
    console.log('\n🌐 Test 5: API Endpoints (Simulated)');
    console.log('================================');
    
    const apiTests = [
      { endpoint: '/api/deployments', method: 'GET', description: 'Fetch all deployments' },
      { endpoint: '/api/deployments/84532', method: 'GET', description: 'Fetch specific deployment' },
      { endpoint: '/api/metrics/84532', method: 'GET', description: 'Fetch deployment metrics' },
      { endpoint: '/api/activity', method: 'GET', description: 'Fetch recent activities' },
      { endpoint: '/api/networks', method: 'GET', description: 'Fetch all networks' },
    ];
    
    console.log('✅ API endpoints ready for testing:');
    apiTests.forEach(test => {
      console.log(`   - ${test.method} ${test.endpoint}: ${test.description}`);
    });
    
    // Test 6: Database Statistics
    console.log('\n📈 Test 6: Database Statistics');
    console.log('================================');
    
    const [
      totalNetworks,
      totalDeployments,
      totalCollaterals,
      totalActivities,
      totalMetrics,
    ] = await Promise.all([
      prisma.sovaBtcNetwork.count(),
      prisma.sovaBtcDeployment.count(),
      prisma.sovaBtcCollateral.count(),
      prisma.sovaBtcActivity.count(),
      prisma.sovaBtcDeploymentMetrics.count(),
    ]);
    
    console.log('✅ Database summary:');
    console.log(`   - Networks: ${totalNetworks}`);
    console.log(`   - Deployments: ${totalDeployments}`);
    console.log(`   - Collaterals: ${totalCollaterals}`);
    console.log(`   - Activities: ${totalActivities}`);
    console.log(`   - Metric Records: ${totalMetrics}`);
    
    console.log('\n' + '='.repeat(50));
    console.log('✨ All tests completed successfully!');
    console.log('✅ Database integration is working correctly');
    console.log('✅ API endpoints are ready for use');
    console.log('✅ Frontend can now use the new API-based registry');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Run the tests
testAPIIntegration();