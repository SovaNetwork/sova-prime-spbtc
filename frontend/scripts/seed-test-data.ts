import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding test data...');

  try {
    // Ensure Base Sepolia network exists
    const network = await prisma.sovaBtcNetwork.upsert({
      where: { chainId: 84532 },
      update: {},
      create: {
        chainId: 84532,
        name: 'Base Sepolia',
        rpcUrl: process.env.BASE_SEPOLIA_RPC_URL || 'https://base-sepolia.g.alchemy.com/v2/demo',
        blockExplorer: 'https://sepolia.basescan.org',
        nativeCurrency: {
          name: 'ETH',
          symbol: 'ETH',
          decimals: 18,
        },
        isTestnet: true,
      },
    });

    console.log('✅ Network:', network.name);

    // Create or update deployment
    const deployment = await prisma.sovaBtcDeployment.upsert({
      where: { chainId: 84532 },
      update: {
        status: 'ACTIVE',
      },
      create: {
        chainId: 84532,
        vaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
        vaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
        priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
        status: 'ACTIVE',
        verified: true,
        blockNumber: 123456,
        transactionHash: '0x' + '0'.repeat(64),
      },
    });

    console.log('✅ Deployment:', deployment.id);

    // Add test collaterals for Base Sepolia with proper chainId
    const collaterals = [
      {
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin (Test)',
        address: '0xCC37f4124214FEEd37ba4d17cD1Dc53F1eF5c818',
        decimals: 8,
        logoUri: 'https://assets.coingecko.com/coins/images/7598/small/wrapped_bitcoin_wbtc.png',
        coingeckoId: 'wrapped-bitcoin',
      },
      {
        symbol: 'sovaBTC',
        name: 'Sova Bitcoin',
        address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
        decimals: 18,
        logoUri: null,
        coingeckoId: null,
      },
    ];

    for (const collateral of collaterals) {
      await prisma.sovaBtcCollateral.upsert({
        where: {
          chainId_address: {
            chainId: 84532,
            address: collateral.address,
          },
        },
        update: {
          isActive: true,
          isVerified: true,
        },
        create: {
          deploymentId: deployment.id,
          symbol: collateral.symbol,
          name: collateral.name,
          address: collateral.address,
          chainId: 84532, // Add chainId here
          decimals: collateral.decimals,
          logoUri: collateral.logoUri,
          coingeckoId: collateral.coingeckoId,
          isActive: true,
          isVerified: true,
        },
      });
    }

    console.log('✅ Collaterals:', collaterals.map(c => c.symbol).join(', '));

    // Add some test metrics
    await prisma.sovaBtcDeploymentMetrics.create({
      data: {
        deploymentId: deployment.id,
        tvl: '1000000.0',
        totalSupply: '900000.0',
        totalAssets: '1000000.0',
        sharePrice: '1.111111',
        apy: '12.5',
        users: 150,
        transactions: 450,
      },
    });

    console.log('✅ Sample metrics added');

    // Add sample activity
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: deployment.id,
        type: 'DEPLOYMENT_CREATED',
        description: 'Test deployment initialized',
        metadata: { testData: true },
      },
    });

    console.log('✅ Sample activity added');

    console.log('\n✅ Test data seeded successfully!');
    console.log('You can now test the collateral management features.');
  } catch (error) {
    console.error('Error seeding data:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});