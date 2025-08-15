import { prisma } from '../lib/prisma';

async function checkAndFixDeployment() {
  try {
    console.log('Checking for existing deployments...');
    
    // Check for existing deployments
    const deployments = await prisma.sovaBtcDeployment.findMany({
      include: {
        network: true,
      },
    });
    
    console.log(`Found ${deployments.length} deployments`);
    
    if (deployments.length === 0) {
      console.log('No deployments found. Creating Base Sepolia deployment...');
      
      // First, ensure the network exists
      let network = await prisma.sovaBtcNetwork.findUnique({
        where: { chainId: 84532 },
      });
      
      if (!network) {
        console.log('Creating Base Sepolia network...');
        network = await prisma.sovaBtcNetwork.create({
          data: {
            chainId: 84532,
            name: 'Base Sepolia',
            rpcUrl: process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC || 'https://sepolia.base.org',
            blockExplorer: 'https://sepolia.basescan.org',
            nativeCurrency: {
              name: 'ETH',
              symbol: 'ETH',
              decimals: 18
            },
            isTestnet: true
          }
        });
        console.log('✅ Created Base Sepolia network');
      }
      
      // Create the deployment
      const deployment = await prisma.sovaBtcDeployment.create({
        data: {
          chainId: 84532,
          vaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
          vaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
          priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
          status: 'ACTIVE',
          deployer: '0x0000000000000000000000000000000000000000',
          blockNumber: 0,
          transactionHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
          verified: true
        }
      });
      
      console.log('✅ Created deployment:', deployment);
      console.log('Deployment ID:', deployment.id);
      
      // Return the deployment for use in the app
      return deployment;
    } else {
      console.log('Existing deployments:');
      deployments.forEach(dep => {
        console.log(`- ID: ${dep.id}`);
        console.log(`  Chain: ${dep.network?.name || dep.chainId}`);
        console.log(`  Vault Token: ${dep.vaultToken}`);
        console.log(`  Status: ${dep.status}`);
      });
      
      return deployments[0];
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

checkAndFixDeployment().then(deployment => {
  if (deployment) {
    console.log('\n✅ Deployment ready to use!');
    console.log('Use this deployment ID in your vault page:', deployment.id);
  }
});