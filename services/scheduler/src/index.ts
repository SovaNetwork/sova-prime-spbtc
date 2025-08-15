import { CronJob } from 'cron';
import express from 'express';
import { PrismaClient } from '@prisma/client';
import { BlockchainService } from '../lib/services/blockchainService.js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const prisma = new PrismaClient({
  log: ['error', 'warn'],
  errorFormat: 'minimal',
});

const app = express();

// Test database connection on startup
async function testDatabaseConnection() {
  try {
    await prisma.$connect();
    const count = await prisma.sovaBtcNetwork.count();
    console.log(`✅ Database connected. Found ${count} networks.`);
  } catch (error) {
    console.error('❌ DATABASE CONNECTION FAILED');
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (error instanceof Error) {
      if (error.message.includes('password authentication failed')) {
        console.error('🔐 AUTHENTICATION ERROR: The database password is incorrect.');
        console.error('📝 TO FIX:');
        console.error('   1. Go to Neon dashboard and copy the correct connection string');
        console.error('   2. Update DATABASE_URL in Railway environment variables');
        console.error('   3. Make sure the password is correctly copied');
      } else if (error.message.includes("Can't reach database server")) {
        console.error('🌐 NETWORK ERROR: Cannot reach the database server.');
        console.error('📝 TO FIX:');
        console.error('   1. Check if the database is active (not paused) in Neon');
        console.error('   2. Verify the connection string is correct');
        console.error('   3. Ensure ?sslmode=require is in the URL');
      } else {
        console.error('Error:', error.message);
      }
    }
    
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('⚠️  Service will continue running without database');
    console.log('⚠️  Fix the DATABASE_URL and redeploy to enable database features');
  }
}

testDatabaseConnection();

// Initialize blockchain service
const blockchainService = new BlockchainService(prisma);

// Track job status
const jobStatus = {
  metricsCollection: {
    lastRun: null as Date | null,
    isRunning: false,
    lastError: null as string | null,
    successCount: 0,
    errorCount: 0,
  },
  collateralSync: {
    lastRun: null as Date | null,
    isRunning: false,
    lastError: null as string | null,
    successCount: 0,
    errorCount: 0,
  },
};

// Metrics collection job - runs every 5 minutes
const metricsJob = new CronJob(
  '*/5 * * * *',
  async () => {
    console.log('[Metrics] Starting metrics collection...');
    jobStatus.metricsCollection.isRunning = true;
    jobStatus.metricsCollection.lastRun = new Date();
    
    try {
      // Get all active deployments
      const deployments = await prisma.sovaBtcDeployment.findMany({
        where: { status: 'ACTIVE' },
        include: { network: true },
      });
      
      console.log(`[Metrics] Found ${deployments.length} active deployments`);
      
      // Process deployments concurrently for better performance
      const metricsPromises = deployments.map(async (deployment) => {
        try {
          console.log(`[Metrics] Collecting metrics for chain ${deployment.chainId}`);
          await blockchainService.fetchRealMetrics(deployment.chainId, deployment.id);
          
          // Log activity
          await prisma.sovaBtcActivity.create({
            data: {
              deploymentId: deployment.id,
              type: 'METRICS_UPDATED',
              description: `Metrics collected for ${deployment.network.name}`,
              metadata: {
                chainId: deployment.chainId,
                deploymentId: deployment.id,
              },
            },
          });
          
          return { success: true, chainId: deployment.chainId };
        } catch (error) {
          console.error(`[Metrics] Error collecting metrics for chain ${deployment.chainId}:`, error);
          return { success: false, chainId: deployment.chainId, error: error instanceof Error ? error.message : String(error) };
        }
      });
      
      const results = await Promise.allSettled(metricsPromises);
      const successful = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
      const failed = results.length - successful;
      
      console.log(`[Metrics] Completed: ${successful} successful, ${failed} failed`);
      
      // Log chain-specific failures
      results.forEach((result, index) => {
        if (result.status === 'fulfilled' && !result.value.success) {
          console.error(`[Metrics] Chain ${result.value.chainId} failed: ${result.value.error}`);
        } else if (result.status === 'rejected') {
          console.error(`[Metrics] Chain ${deployments[index].chainId} rejected:`, result.reason);
        }
      });
      
      jobStatus.metricsCollection.successCount++;
      jobStatus.metricsCollection.lastError = null;
      console.log('[Metrics] Metrics collection completed successfully');
    } catch (error) {
      console.error('[Metrics] Metrics collection failed:', error);
      jobStatus.metricsCollection.errorCount++;
      jobStatus.metricsCollection.lastError = error instanceof Error ? error.message : 'Unknown error';
    } finally {
      jobStatus.metricsCollection.isRunning = false;
    }
  },
  null,
  true, // Start immediately
  'UTC'
);

// Collateral sync job - runs every hour
const collateralSyncJob = new CronJob(
  '0 * * * *',
  async () => {
    console.log('[Collateral] Starting collateral sync...');
    jobStatus.collateralSync.isRunning = true;
    jobStatus.collateralSync.lastRun = new Date();
    
    try {
      // Get all active deployments
      const deployments = await prisma.sovaBtcDeployment.findMany({
        where: { status: 'ACTIVE' },
        include: { network: true },
      });
      
      console.log(`[Collateral] Found ${deployments.length} active deployments`);
      
      // Process deployments concurrently for better performance
      const syncPromises = deployments.map(async (deployment) => {
        try {
          console.log(`[Collateral] Syncing collaterals for chain ${deployment.chainId}`);
          await blockchainService.syncCollateralsToDatabase(deployment.chainId, deployment.id);
          
          // Log activity
          await prisma.sovaBtcActivity.create({
            data: {
              deploymentId: deployment.id,
              type: 'DEPLOYMENT_UPDATED',
              description: `Collaterals synced for ${deployment.network.name}`,
              metadata: {
                chainId: deployment.chainId,
                deploymentId: deployment.id,
              },
            },
          });
          
          return { success: true, chainId: deployment.chainId };
        } catch (error) {
          console.error(`[Collateral] Error syncing collaterals for chain ${deployment.chainId}:`, error);
          return { success: false, chainId: deployment.chainId, error: error instanceof Error ? error.message : String(error) };
        }
      });
      
      const results = await Promise.allSettled(syncPromises);
      const successful = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
      const failed = results.length - successful;
      
      console.log(`[Collateral] Completed: ${successful} successful, ${failed} failed`);
      
      // Log chain-specific failures
      results.forEach((result, index) => {
        if (result.status === 'fulfilled' && !result.value.success) {
          console.error(`[Collateral] Chain ${result.value.chainId} failed: ${result.value.error}`);
        } else if (result.status === 'rejected') {
          console.error(`[Collateral] Chain ${deployments[index].chainId} rejected:`, result.reason);
        }
      });
      
      jobStatus.collateralSync.successCount++;
      jobStatus.collateralSync.lastError = null;
      console.log('[Collateral] Collateral sync completed successfully');
    } catch (error) {
      console.error('[Collateral] Collateral sync failed:', error);
      jobStatus.collateralSync.errorCount++;
      jobStatus.collateralSync.lastError = error instanceof Error ? error.message : 'Unknown error';
    } finally {
      jobStatus.collateralSync.isRunning = false;
    }
  },
  null,
  true, // Start immediately
  'UTC'
);

// Health check endpoint
app.get('/health', (req, res) => {
  // Service is healthy if it's not stuck (jobs should not be running continuously)
  const metricsStuck = jobStatus.metricsCollection.isRunning && 
    jobStatus.metricsCollection.lastRun && 
    (Date.now() - jobStatus.metricsCollection.lastRun.getTime() > 10 * 60 * 1000); // Stuck if running for >10 min
  
  const collateralStuck = jobStatus.collateralSync.isRunning && 
    jobStatus.collateralSync.lastRun && 
    (Date.now() - jobStatus.collateralSync.lastRun.getTime() > 10 * 60 * 1000);
  
  const isHealthy = !metricsStuck && !collateralStuck;
  
  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'healthy' : 'degraded',
    timestamp: new Date(),
    jobs: {
      metricsCollection: {
        ...jobStatus.metricsCollection,
        nextRun: metricsJob.nextDate()?.toJSDate(),
      },
      collateralSync: {
        ...jobStatus.collateralSync,
        nextRun: collateralSyncJob.nextDate()?.toJSDate(),
      },
    },
  });
});

// Status endpoint with more details
app.get('/status', (req, res) => {
  res.json({
    service: 'sovabtc-scheduler',
    version: '1.0.0',
    uptime: process.uptime(),
    timestamp: new Date(),
    environment: process.env.NODE_ENV || 'development',
    jobs: {
      metricsCollection: {
        ...jobStatus.metricsCollection,
        running: metricsJob.running,
        nextRun: metricsJob.nextDate()?.toJSDate(),
      },
      collateralSync: {
        ...jobStatus.collateralSync,
        running: collateralSyncJob.running,
        nextRun: collateralSyncJob.nextDate()?.toJSDate(),
      },
    },
  });
});

// Manual trigger endpoints (for testing)
if (process.env.NODE_ENV !== 'production') {
  app.post('/trigger/metrics', async (req, res) => {
    if (jobStatus.metricsCollection.isRunning) {
      return res.status(409).json({ error: 'Metrics collection already running' });
    }
    
    // Trigger the job manually
    metricsJob.fireOnTick();
    res.json({ message: 'Metrics collection triggered' });
  });
  
  app.post('/trigger/collaterals', async (req, res) => {
    if (jobStatus.collateralSync.isRunning) {
      return res.status(409).json({ error: 'Collateral sync already running' });
    }
    
    // Trigger the job manually
    collateralSyncJob.fireOnTick();
    res.json({ message: 'Collateral sync triggered' });
  });
}

// Start the server
const PORT = process.env.SCHEDULER_PORT || 3001;
app.listen(PORT, () => {
  console.log(`✅ Scheduler service running on port ${PORT}`);
  console.log(`📊 Metrics collection: Every 5 minutes`);
  console.log(`🔄 Collateral sync: Every hour`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
  console.log(`📈 Status: http://localhost:${PORT}/status`);
  
  if (process.env.NODE_ENV !== 'production') {
    console.log(`🔧 Manual triggers available (dev mode):`);
    console.log(`   POST http://localhost:${PORT}/trigger/metrics`);
    console.log(`   POST http://localhost:${PORT}/trigger/collaterals`);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  
  // Stop cron jobs
  metricsJob.stop();
  collateralSyncJob.stop();
  
  // Close database connection
  await prisma.$disconnect();
  
  process.exit(0);
});