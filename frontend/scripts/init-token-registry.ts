import { PrismaClient } from '@prisma/client';
import { BlockchainService } from '../lib/services/blockchainService';

const prisma = new PrismaClient();

async function main() {
  console.log('Initializing token registry...');

  const blockchainService = new BlockchainService(prisma);
  
  try {
    // Initialize with common BTC tokens
    await blockchainService.initializeTokenRegistry();
    
    // Also ensure we have the Base Sepolia network and deployment
    const network = await prisma.sovaBtcNetwork.upsert({
      where: { chainId: 84532 },
      update: {},
      create: {
        chainId: 84532,
        name: 'Base Sepolia',
        rpcUrl: 'https://base-sepolia.g.alchemy.com/v2/demo',
        blockExplorer: 'https://sepolia.basescan.org',
        nativeCurrency: {
          name: 'ETH',
          symbol: 'ETH',
          decimals: 18,
        },
        isTestnet: true,
      },
    });

    console.log('✅ Network configured:', network.name);

    // Check if deployment exists
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId: 84532 },
    });

    if (deployment) {
      // Add test collaterals for Base Sepolia
      const testCollaterals = [
        {
          symbol: 'WBTC',
          name: 'Wrapped Bitcoin (Test)',
          address: '0xCC37f4124214FEEd37ba4d17cD1Dc53F1eF5c818',
          chainId: 84532,
          decimals: 8,
        },
        {
          symbol: 'sovaBTC',
          name: 'Sova Bitcoin',
          address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
          chainId: 84532,
          decimals: 18,
        },
      ];

      for (const collateral of testCollaterals) {
        await prisma.sovaBtcCollateral.upsert({
          where: {
            chainId_address: {
              chainId: collateral.chainId,
              address: collateral.address,
            },
          },
          update: {
            isActive: true,
          },
          create: {
            deploymentId: deployment.id,
            symbol: collateral.symbol,
            name: collateral.name,
            address: collateral.address,
            chainId: collateral.chainId,
            decimals: collateral.decimals,
            isActive: true,
            isVerified: true,
          },
        });
      }

      console.log('✅ Test collaterals configured for Base Sepolia');
    }

    console.log('✅ Token registry initialized successfully');
  } catch (error) {
    console.error('Failed to initialize token registry:', error);
    throw error;
  } finally {
    await blockchainService.disconnect();
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});