#!/usr/bin/env npx tsx

/**
 * Multi-Chain Implementation Test Script
 * 
 * This script tests the multi-chain functionality by:
 * 1. Checking database connectivity
 * 2. Verifying network configurations
 * 3. Testing blockchain service connections
 * 4. Validating API endpoints
 * 
 * Usage: npx tsx scripts/test-multi-chain.ts
 */

import { PrismaClient } from '@prisma/client';
import { BlockchainService } from '../services/scheduler/lib/services/blockchainService.js';

const prisma = new PrismaClient();

interface TestResult {
  test: string;
  status: 'PASS' | 'FAIL' | 'SKIP';
  message?: string;
  data?: any;
}

class MultiChainTester {
  private results: TestResult[] = [];
  
  private log(test: string, status: 'PASS' | 'FAIL' | 'SKIP', message?: string, data?: any) {
    this.results.push({ test, status, message, data });
    const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⚠️';
    console.log(`${icon} ${test}: ${message || status}`);
    if (data && process.env.VERBOSE === 'true') {
      console.log('   Data:', JSON.stringify(data, null, 2));
    }
  }
  
  async testDatabaseConnection() {
    try {
      await prisma.$connect();
      const networkCount = await prisma.sovaBtcNetwork.count();
      const deploymentCount = await prisma.sovaBtcDeployment.count();
      
      this.log(
        'Database Connection',
        'PASS',
        `Connected. ${networkCount} networks, ${deploymentCount} deployments`,
        { networks: networkCount, deployments: deploymentCount }
      );
    } catch (error) {
      this.log('Database Connection', 'FAIL', error.message);
    }
  }
  
  async testNetworkConfigurations() {
    try {
      const networks = await prisma.sovaBtcNetwork.findMany({
        include: {
          deployments: true,
          metrics: {
            orderBy: { timestamp: 'desc' },
            take: 1,
          },
        },
      });
      
      if (networks.length === 0) {
        this.log('Network Configurations', 'FAIL', 'No networks found in database');
        return;
      }
      
      for (const network of networks) {
        const hasDeployment = network.deployments.length > 0;
        const hasMetrics = network.metrics.length > 0;
        
        this.log(
          `Network: ${network.name}`,
          hasDeployment ? 'PASS' : 'SKIP',
          `ChainId: ${network.chainId}, Deployment: ${hasDeployment ? 'Yes' : 'No'}, Metrics: ${hasMetrics ? 'Yes' : 'No'}`,
          {
            chainId: network.chainId,
            isTestnet: network.isTestnet,
            hasDeployment,
            hasMetrics,
            deploymentStatus: network.deployments[0]?.status,
          }
        );
      }
    } catch (error) {
      this.log('Network Configurations', 'FAIL', error.message);
    }
  }
  
  async testBlockchainConnections() {
    try {
      const blockchainService = new BlockchainService(prisma);
      
      const activeDeployments = await prisma.sovaBtcDeployment.findMany({
        where: { status: 'ACTIVE' },
        include: { network: true },
      });
      
      if (activeDeployments.length === 0) {
        this.log('Blockchain Connections', 'SKIP', 'No active deployments to test');
        return;
      }
      
      for (const deployment of activeDeployments) {
        try {
          // Test connection by trying to get known collaterals
          const collaterals = await blockchainService.fetchCollateralsFromChain(
            deployment.chainId,
            deployment.vaultStrategy
          );
          
          this.log(
            `Blockchain: ${deployment.network.name}`,
            'PASS',
            `Connected. Found ${collaterals.length} collaterals`,
            { chainId: deployment.chainId, collaterals: collaterals.length }
          );
        } catch (error) {
          this.log(
            `Blockchain: ${deployment.network.name}`,
            'FAIL',
            `Connection failed: ${error.message}`,
            { chainId: deployment.chainId, error: error.message }
          );
        }
      }
      
      await blockchainService.disconnect();
    } catch (error) {
      this.log('Blockchain Connections', 'FAIL', error.message);
    }
  }
  
  async testPonderConfiguration() {
    try {
      const enabledNetworks = (process.env.PONDER_ENABLED_NETWORKS || 'baseSepolia')
        .split(',')
        .map(n => n.trim());
      
      this.log(
        'Ponder Configuration',
        enabledNetworks.length > 0 ? 'PASS' : 'FAIL',
        `Enabled networks: ${enabledNetworks.join(', ')}`,
        { enabledNetworks }
      );
      
      // Check if enabled networks have deployments
      for (const networkName of enabledNetworks) {
        const chainId = this.getChainIdFromNetworkName(networkName);
        if (chainId) {
          const deployment = await prisma.sovaBtcDeployment.findUnique({
            where: { chainId },
            include: { network: true },
          });
          
          this.log(
            `Ponder Network: ${networkName}`,
            deployment ? 'PASS' : 'FAIL',
            deployment 
              ? `Deployment found (${deployment.status})`
              : 'No deployment found',
            { chainId, hasDeployment: !!deployment }
          );
        } else {
          this.log(
            `Ponder Network: ${networkName}`,
            'FAIL',
            'Unknown network name'
          );
        }
      }
    } catch (error) {
      this.log('Ponder Configuration', 'FAIL', error.message);
    }
  }
  
  async testAPIEndpoints() {
    try {
      const apiTests = [
        { endpoint: '/api/networks', description: 'Networks API' },
        { endpoint: '/api/metrics/aggregate', description: 'Aggregated Metrics API' },
        { endpoint: '/api/collaterals/summary', description: 'Collaterals Summary API' },
        { endpoint: '/api/activity', description: 'Activity API' },
      ];
      
      // Since we can't make HTTP requests in this context without a server,
      // we'll simulate by checking if the route files exist
      const fs = await import('fs').then(m => m.promises);
      const path = await import('path');
      
      for (const test of apiTests) {
        try {
          const routePath = path.join(process.cwd(), 'frontend/app/api', test.endpoint.replace('/api/', ''), 'route.ts');
          await fs.access(routePath);
          this.log(test.description, 'PASS', 'Route file exists');
        } catch {
          this.log(test.description, 'FAIL', 'Route file not found');
        }
      }
    } catch (error) {
      this.log('API Endpoints', 'FAIL', error.message);
    }
  }
  
  private getChainIdFromNetworkName(networkName: string): number | null {
    const chainIds: Record<string, number> = {
      'baseSepolia': 84532,
      'ethereum': 1,
      'base': 8453,
      'arbitrum': 42161,
      'optimism': 10,
      'sepolia': 11155111,
    };
    return chainIds[networkName] || null;
  }
  
  async runAllTests() {
    console.log('🧪 Starting Multi-Chain Implementation Tests\n');
    
    await this.testDatabaseConnection();
    await this.testNetworkConfigurations();
    await this.testBlockchainConnections();
    await this.testPonderConfiguration();
    await this.testAPIEndpoints();
    
    console.log('\n📊 Test Results Summary:');
    const passed = this.results.filter(r => r.status === 'PASS').length;
    const failed = this.results.filter(r => r.status === 'FAIL').length;
    const skipped = this.results.filter(r => r.status === 'SKIP').length;
    
    console.log(`✅ Passed: ${passed}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`⚠️  Skipped: ${skipped}`);
    console.log(`📈 Success Rate: ${((passed / (passed + failed)) * 100).toFixed(1)}%`);
    
    if (failed > 0) {
      console.log('\n❌ Failed Tests:');
      this.results
        .filter(r => r.status === 'FAIL')
        .forEach(result => console.log(`   - ${result.test}: ${result.message}`));
    }
    
    console.log('\n💡 Recommendations:');
    if (failed === 0 && skipped === 0) {
      console.log('   🎉 All tests passed! Multi-chain implementation is working correctly.');
    } else {
      console.log('   📝 Review failed tests and update configuration as needed.');
      console.log('   🔧 Ensure RPC endpoints are configured in .env file.');
      console.log('   🚀 Deploy missing contracts and update deployment entries.');
      console.log('   📚 See multi-chain.config.example.env for configuration guidance.');
    }
    
    return failed === 0;
  }
}

async function main() {
  const tester = new MultiChainTester();
  
  try {
    const success = await tester.runAllTests();
    process.exit(success ? 0 : 1);
  } catch (error) {
    console.error('❌ Test execution failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main();
}

export { MultiChainTester };