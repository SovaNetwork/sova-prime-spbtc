#!/usr/bin/env npx tsx

/**
 * Network Setup Script for SovaBTC Multi-Chain
 * 
 * This script helps initialize a new network in the database
 * and update the necessary configuration files.
 * 
 * Usage: npx tsx scripts/setup-network.ts <chainId>
 * Example: npx tsx scripts/setup-network.ts 8453
 */

import { PrismaClient } from '@prisma/client';
import { NETWORK_TEMPLATES, getNetworkTemplate } from '../frontend/lib/deployments/networks';

const prisma = new PrismaClient();

interface NetworkSetupData {
  chainId: number;
  vaultToken?: string;
  vaultStrategy?: string;
  startBlock?: number;
  deployerAddress?: string;
  txHash?: string;
}

async function setupNetwork(data: NetworkSetupData) {
  const { chainId } = data;
  
  console.log(`🚀 Setting up network for chainId: ${chainId}`);
  
  // Get network template
  const networkTemplate = getNetworkTemplate(chainId);
  if (!networkTemplate) {
    throw new Error(`No network template found for chainId ${chainId}`);
  }
  
  console.log(`📡 Network: ${networkTemplate.name}`);
  
  try {
    // 1. Create or update network entry
    console.log('📝 Creating/updating network entry...');
    const network = await prisma.sovaBtcNetwork.upsert({
      where: { chainId },
      update: {
        name: networkTemplate.name,
        rpcUrl: networkTemplate.rpcUrl,
        blockExplorer: networkTemplate.blockExplorer,
        nativeCurrency: networkTemplate.nativeCurrency,
        isTestnet: [11155111, 84532, 421614, 11155420, 80002, 43113].includes(chainId),
      },
      create: {
        chainId,
        name: networkTemplate.name,
        rpcUrl: networkTemplate.rpcUrl,
        blockExplorer: networkTemplate.blockExplorer,
        nativeCurrency: networkTemplate.nativeCurrency,
        isTestnet: [11155111, 84532, 421614, 11155420, 80002, 43113].includes(chainId),
      },
    });
    
    console.log(`✅ Network created/updated: ${network.name} (${network.chainId})`);
    
    // 2. Create deployment entry if contract addresses provided
    if (data.vaultToken && data.vaultStrategy) {
      console.log('📝 Creating deployment entry...');
      const deployment = await prisma.sovaBtcDeployment.upsert({
        where: { chainId },
        update: {
          vaultToken: data.vaultToken,
          vaultStrategy: data.vaultStrategy,
          blockNumber: data.startBlock,
          transactionHash: data.txHash,
          deployer: data.deployerAddress,
          status: 'ACTIVE',
        },
        create: {
          chainId,
          vaultToken: data.vaultToken,
          vaultStrategy: data.vaultStrategy,
          blockNumber: data.startBlock,
          transactionHash: data.txHash,
          deployer: data.deployerAddress,
          status: 'ACTIVE',
        },
      });
      
      console.log(`✅ Deployment created/updated: ${deployment.id}`);
      
      // 3. Initialize token registry if needed
      console.log('📝 Initializing token registry...');
      const { BlockchainService } = await import('../services/scheduler/lib/services/blockchainService.js');
      const blockchainService = new BlockchainService(prisma);
      await blockchainService.initializeTokenRegistry();
      console.log('✅ Token registry initialized');
      
    } else {
      console.log('⚠️  Contract addresses not provided, skipping deployment creation');
      console.log('   You can create the deployment later using:');
      console.log(`   POST /api/deployments`);
    }
    
    // 4. Display next steps
    console.log('\n🎉 Network setup completed!');
    console.log('\n📋 Next steps:');
    console.log('1. Update your .env file to include RPC URL for this chain');
    console.log('2. Add this network to PONDER_ENABLED_NETWORKS if you want to index it');
    console.log('3. Update services/indexer/ponder.config.ts with contract addresses');
    console.log('4. Restart the indexer and scheduler services');
    console.log('5. Verify the frontend can switch to this network');
    
    if (!data.vaultToken || !data.vaultStrategy) {
      console.log('\n⚠️  Contract addresses not provided. Remember to:');
      console.log('   - Deploy contracts to this network');
      console.log('   - Create deployment entry via API');
      console.log('   - Update indexer configuration');
    }
    
    console.log(`\n🔗 Network explorer: ${networkTemplate.blockExplorer}`);
    
  } catch (error) {
    console.error('❌ Network setup failed:', error);
    throw error;
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage: npx tsx scripts/setup-network.ts <chainId> [vaultToken] [vaultStrategy] [startBlock]');
    console.log('\nExamples:');
    console.log('  npx tsx scripts/setup-network.ts 8453  # Setup Base mainnet (no contracts)');
    console.log('  npx tsx scripts/setup-network.ts 8453 0x123... 0x456... 12345678  # With contracts');
    console.log('\nSupported networks:');
    Object.entries(NETWORK_TEMPLATES).forEach(([key, network]) => {
      console.log(`  ${network.chainId}: ${network.name} (${key})`);
    });
    process.exit(1);
  }
  
  const chainId = parseInt(args[0]);
  if (isNaN(chainId)) {
    console.error('❌ Invalid chainId. Must be a number.');
    process.exit(1);
  }
  
  const setupData: NetworkSetupData = {
    chainId,
    vaultToken: args[1],
    vaultStrategy: args[2],
    startBlock: args[3] ? parseInt(args[3]) : undefined,
  };
  
  try {
    await setupNetwork(setupData);
  } catch (error) {
    console.error('❌ Setup failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main();
}

export { setupNetwork };