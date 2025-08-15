import { prisma } from '../lib/prisma';

async function testConnection() {
  try {
    console.log('Testing database connection...');
    
    // Test connection
    await prisma.$connect();
    console.log('✅ Database connected successfully');
    
    // Test creating a network
    const testNetwork = await prisma.sovaBtcNetwork.create({
      data: {
        chainId: 84532,
        name: 'Base Sepolia',
        rpcUrl: 'https://sepolia.base.org',
        blockExplorer: 'https://sepolia.basescan.org',
        nativeCurrency: {
          name: 'ETH',
          symbol: 'ETH',
          decimals: 18
        },
        isTestnet: true
      }
    });
    console.log('✅ Created test network:', testNetwork);
    
    // Test reading
    const networks = await prisma.sovaBtcNetwork.findMany();
    console.log('✅ Found networks:', networks.length);
    
    // Clean up
    await prisma.sovaBtcNetwork.delete({
      where: { id: testNetwork.id }
    });
    console.log('✅ Cleaned up test data');
    
    await prisma.$disconnect();
    console.log('✅ All database tests passed!');
    
  } catch (error) {
    console.error('❌ Database test failed:', error);
    process.exit(1);
  }
}

testConnection();