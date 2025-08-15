import { prisma } from '../lib/prisma';

async function addTestMetrics() {
  console.log('📊 Adding test metrics to database...\n');
  
  try {
    // Get deployment
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId: 84532 },
    });
    
    if (!deployment) {
      throw new Error('Deployment not found for chain 84532');
    }
    
    // Add multiple metrics with different timestamps
    const metricsData = [
      { tvl: '1000.00', apy: 5.5, users: 42, transactions: 156, offset: 0 },
      { tvl: '1100.00', apy: 5.6, users: 45, transactions: 162, offset: -1 },
      { tvl: '1050.00', apy: 5.4, users: 44, transactions: 160, offset: -2 },
      { tvl: '950.00', apy: 5.3, users: 40, transactions: 150, offset: -3 },
      { tvl: '900.00', apy: 5.2, users: 38, transactions: 145, offset: -4 },
    ];
    
    for (const data of metricsData) {
      const timestamp = new Date();
      timestamp.setHours(timestamp.getHours() + data.offset);
      
      const metric = await prisma.sovaBtcDeploymentMetrics.create({
        data: {
          deploymentId: deployment.id,
          tvl: data.tvl,
          totalSupply: data.tvl,
          totalAssets: data.tvl,
          sharePrice: '1.00',
          apy: data.apy,
          users: data.users,
          transactions: data.transactions,
          timestamp,
        },
      });
      
      console.log(`✅ Added metrics for ${timestamp.toLocaleString()}`);
      console.log(`   TVL: ${data.tvl}, APY: ${data.apy}%, Users: ${data.users}`);
    }
    
    // Add network metrics
    console.log('\n📡 Adding network metrics...');
    
    for (let i = 0; i < 5; i++) {
      const timestamp = new Date();
      timestamp.setMinutes(timestamp.getMinutes() - (i * 10));
      
      await prisma.sovaBtcNetworkMetrics.create({
        data: {
          chainId: 84532,
          blockHeight: BigInt(1000000 + i * 100),
          gasPrice: BigInt(20 + i) * BigInt(10 ** 9), // 20-24 gwei
          isOnline: true,
          latency: 50 + Math.floor(Math.random() * 50),
          timestamp,
        },
      });
      
      console.log(`✅ Added network metrics for ${timestamp.toLocaleString()}`);
    }
    
    // Add more activities
    console.log('\n📝 Adding test activities...');
    
    const activityTypes = [
      { type: 'USER_DEPOSIT', description: 'User deposited 0.5 WBTC' },
      { type: 'USER_WITHDRAWAL', description: 'User withdrew 0.2 sovaBTC' },
      { type: 'METRICS_UPDATED', description: 'Automated metrics collection' },
      { type: 'COLLATERAL_ADDED', description: 'Added tBTC as supported collateral' },
      { type: 'STATUS_CHANGED', description: 'Deployment status changed to ACTIVE' },
    ];
    
    for (const activity of activityTypes) {
      await prisma.sovaBtcActivity.create({
        data: {
          deploymentId: deployment.id,
          type: activity.type as any,
          description: activity.description,
          metadata: {
            test: true,
            createdBy: 'test-script',
          },
        },
      });
      
      console.log(`✅ Added activity: ${activity.description}`);
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('✨ Test data added successfully!');
    
    // Show summary
    const [totalMetrics, totalNetworkMetrics, totalActivities] = await Promise.all([
      prisma.sovaBtcDeploymentMetrics.count(),
      prisma.sovaBtcNetworkMetrics.count(),
      prisma.sovaBtcActivity.count(),
    ]);
    
    console.log('\n📈 Database now contains:');
    console.log(`   - Deployment Metrics: ${totalMetrics}`);
    console.log(`   - Network Metrics: ${totalNetworkMetrics}`);
    console.log(`   - Activities: ${totalActivities}`);
    
  } catch (error) {
    console.error('❌ Failed to add test metrics:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Run the script
addTestMetrics();