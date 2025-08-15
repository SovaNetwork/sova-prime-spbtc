import { prisma } from '../lib/prisma';
import { DeploymentStatus } from '@prisma/client';

// Mock localStorage data structure (for testing)
const mockLocalStorageData = {
  "84532": {
    network: {
      chainId: 84532,
      name: 'Base Sepolia',
      rpcUrl: 'https://sepolia.base.org',
      blockExplorer: 'https://sepolia.basescan.org',
      nativeCurrency: {
        name: 'ETH',
        symbol: 'ETH',
        decimals: 18,
      },
    },
    contracts: {
      btcVaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
      btcVaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
      priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
    },
    collaterals: {
      WBTC: {
        address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
        decimals: 8,
        name: 'Wrapped Bitcoin',
        symbol: 'WBTC',
      },
      sovaBTC: {
        address: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
        decimals: 8,
        name: 'Sova Bitcoin',
        symbol: 'sovaBTC',
      },
    },
    deployment: {
      timestamp: '2024-12-10T00:00:00Z',
      blockNumber: 1000000,
      deployer: '0x0000000000000000000000000000000000000000',
      verified: true,
    },
    status: 'active',
  },
};

async function migrateLocalStorageToDatabase() {
  console.log('🚀 Starting localStorage to database migration...');
  
  try {
    // In a real scenario, you would read from actual localStorage
    // For this script, we'll use the mock data
    const localStorageData = mockLocalStorageData;
    
    let migratedCount = 0;
    let skippedCount = 0;
    
    for (const [chainIdStr, deploymentInfo] of Object.entries(localStorageData)) {
      const chainId = parseInt(chainIdStr);
      
      console.log(`\n📦 Processing deployment for chain ${chainId} (${deploymentInfo.network.name})...`);
      
      // Check if deployment already exists
      const existingDeployment = await prisma.sovaBtcDeployment.findUnique({
        where: { chainId },
      });
      
      if (existingDeployment) {
        console.log(`⚠️  Deployment already exists for chain ${chainId}, skipping...`);
        skippedCount++;
        continue;
      }
      
      // Ensure network exists
      let network = await prisma.sovaBtcNetwork.findUnique({
        where: { chainId },
      });
      
      if (!network) {
        console.log(`📡 Creating network for ${deploymentInfo.network.name}...`);
        network = await prisma.sovaBtcNetwork.create({
          data: {
            chainId,
            name: deploymentInfo.network.name,
            rpcUrl: deploymentInfo.network.rpcUrl,
            blockExplorer: deploymentInfo.network.blockExplorer,
            nativeCurrency: deploymentInfo.network.nativeCurrency,
            isTestnet: deploymentInfo.network.name.toLowerCase().includes('test') || 
                      deploymentInfo.network.name.toLowerCase().includes('sepolia'),
          },
        });
      }
      
      // Convert status
      let status: DeploymentStatus;
      switch (deploymentInfo.status) {
        case 'active':
          status = DeploymentStatus.ACTIVE;
          break;
        case 'pending':
          status = DeploymentStatus.PENDING;
          break;
        case 'deprecated':
          status = DeploymentStatus.DEPRECATED;
          break;
        default:
          status = DeploymentStatus.NOT_DEPLOYED;
      }
      
      // Create deployment
      console.log(`💾 Creating deployment...`);
      const deployment = await prisma.sovaBtcDeployment.create({
        data: {
          chainId,
          vaultStrategy: deploymentInfo.contracts.btcVaultStrategy,
          vaultToken: deploymentInfo.contracts.btcVaultToken,
          priceOracle: deploymentInfo.contracts.priceOracle || null,
          status,
          deployer: deploymentInfo.deployment.deployer,
          blockNumber: deploymentInfo.deployment.blockNumber,
          verified: deploymentInfo.deployment.verified,
          collaterals: {
            create: Object.values(deploymentInfo.collaterals).map((collateral: any) => ({
              symbol: collateral.symbol,
              name: collateral.name,
              address: collateral.address,
              decimals: collateral.decimals,
              oracleId: collateral.oracleId,
            })),
          },
          activities: {
            create: {
              type: 'DEPLOYMENT_CREATED',
              description: `Migrated from localStorage`,
              metadata: {
                source: 'localStorage',
                migratedAt: new Date().toISOString(),
              },
            },
          },
        },
        include: {
          collaterals: true,
          activities: true,
        },
      });
      
      console.log(`✅ Successfully migrated deployment for chain ${chainId}`);
      console.log(`   - Vault Strategy: ${deployment.vaultStrategy}`);
      console.log(`   - Vault Token: ${deployment.vaultToken}`);
      console.log(`   - Collaterals: ${deployment.collaterals.map(c => c.symbol).join(', ')}`);
      
      // Add initial metrics (mock data for now)
      console.log(`📊 Adding initial metrics...`);
      await prisma.sovaBtcDeploymentMetrics.create({
        data: {
          deploymentId: deployment.id,
          tvl: '1000.0000000000', // 1000 tokens (with 10 decimal places)
          totalSupply: '1000.0000000000',
          totalAssets: '1000.0000000000',
          sharePrice: '1.0000000000', // 1:1
          apy: 5.5,
          users: 42,
          transactions: 156,
        },
      });
      
      migratedCount++;
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('✨ Migration completed successfully!');
    console.log(`📊 Summary:`);
    console.log(`   - Migrated: ${migratedCount} deployments`);
    console.log(`   - Skipped: ${skippedCount} deployments (already existed)`);
    console.log(`   - Total processed: ${migratedCount + skippedCount}`);
    
    // Verify migration
    const totalDeployments = await prisma.sovaBtcDeployment.count();
    const totalNetworks = await prisma.sovaBtcNetwork.count();
    const totalCollaterals = await prisma.sovaBtcCollateral.count();
    
    console.log('\n📈 Database statistics:');
    console.log(`   - Total deployments: ${totalDeployments}`);
    console.log(`   - Total networks: ${totalNetworks}`);
    console.log(`   - Total collaterals: ${totalCollaterals}`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Run the migration
migrateLocalStorageToDatabase();