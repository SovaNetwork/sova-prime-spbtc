import { ethers } from 'ethers';
import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

// Configuration
interface MonitorConfig {
  rpcUrl: string;
  alertWebhook?: string;
  vaultAddress: string;
  queueAddress: string;
  strategyAddress: string;
  priceOracleAddress: string;
  indexerUrl?: string;
  checkInterval: number; // in milliseconds
}

// Health check interface
interface HealthCheck {
  name: string;
  check: () => Promise<boolean>;
  critical: boolean;
}

interface HealthCheckResult {
  name: string;
  success: boolean;
  error?: string;
  timestamp: number;
}

// Simplified ABI for the contracts we need to monitor
const VAULT_ABI = [
  'function paused() view returns (bool)',
  'function totalSupply() view returns (uint256)',
];

const QUEUE_ABI = [
  'function totalPendingShares() view returns (uint256)',
  'function REDEMPTION_DELAY() view returns (uint256)',
];

const STRATEGY_ABI = [
  'function getTotalValue() view returns (uint256)',
];

const PRICE_ORACLE_ABI = [
  'function lastUpdate() view returns (uint256)',
  'function currentPrice() view returns (uint256)',
];

class HealthMonitor {
  private provider: ethers.JsonRpcProvider;
  private checks: HealthCheck[] = [];
  private config: MonitorConfig;
  private lastAlertTime: Map<string, number> = new Map();
  private alertCooldown = 300000; // 5 minutes cooldown per alert type

  constructor(config: MonitorConfig) {
    this.config = config;
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.setupChecks();
  }

  private setupChecks() {
    // Core contract checks
    this.checks = [
      {
        name: 'Vault Not Paused',
        critical: true,
        check: async () => {
          try {
            const vault = new ethers.Contract(
              this.config.vaultAddress,
              VAULT_ABI,
              this.provider
            );
            const isPaused = await vault.paused();
            return !isPaused;
          } catch (error) {
            console.error('Error checking vault pause status:', error);
            return false;
          }
        }
      },
      {
        name: 'Price Oracle Freshness',
        critical: true,
        check: async () => {
          try {
            const oracle = new ethers.Contract(
              this.config.priceOracleAddress,
              PRICE_ORACLE_ABI,
              this.provider
            );
            const lastUpdate = await oracle.lastUpdate();
            const now = Math.floor(Date.now() / 1000);
            const timeSinceUpdate = now - Number(lastUpdate);
            // Alert if price hasn't been updated in 24 hours
            return timeSinceUpdate < 86400;
          } catch (error) {
            console.error('Error checking price oracle:', error);
            return false;
          }
        }
      },
      {
        name: 'Redemption Queue Processing',
        critical: false,
        check: async () => {
          try {
            const queue = new ethers.Contract(
              this.config.queueAddress,
              QUEUE_ABI,
              this.provider
            );
            const pendingShares = await queue.totalPendingShares();
            const redemptionDelay = await queue.REDEMPTION_DELAY();
            
            // This is a simplified check - in production you'd check specific requests
            // Alert if there are pending shares and they might be overdue
            if (Number(pendingShares) > 0) {
              console.log(`Pending redemptions: ${ethers.formatEther(pendingShares)} shares`);
              // In production, check if oldest request is > redemptionDelay + buffer
              return true; // For now, just log it
            }
            return true;
          } catch (error) {
            console.error('Error checking redemption queue:', error);
            return false;
          }
        }
      },
      {
        name: 'Strategy Liquidity Check',
        critical: true,
        check: async () => {
          try {
            const strategy = new ethers.Contract(
              this.config.strategyAddress,
              STRATEGY_ABI,
              this.provider
            );
            const queue = new ethers.Contract(
              this.config.queueAddress,
              QUEUE_ABI,
              this.provider
            );
            
            const totalValue = await strategy.getTotalValue();
            const pendingShares = await queue.totalPendingShares();
            
            // Check if strategy has enough liquidity for pending redemptions
            // This is simplified - actual calculation would need to convert shares to assets
            const hasLiquidity = Number(totalValue) > 0 || Number(pendingShares) === 0;
            
            if (!hasLiquidity) {
              console.log('Warning: Strategy may have insufficient liquidity');
            }
            
            return hasLiquidity;
          } catch (error) {
            console.error('Error checking strategy liquidity:', error);
            return false;
          }
        }
      },
      {
        name: 'RPC Connection',
        critical: true,
        check: async () => {
          try {
            const blockNumber = await this.provider.getBlockNumber();
            return blockNumber > 0;
          } catch (error) {
            console.error('Error checking RPC connection:', error);
            return false;
          }
        }
      }
    ];

    // Add indexer check if configured
    if (this.config.indexerUrl) {
      this.checks.push({
        name: 'Ponder Indexer Health',
        critical: false,
        check: async () => {
          try {
            const response = await axios.get(`${this.config.indexerUrl}/health`, {
              timeout: 5000
            });
            return response.status === 200 && response.data?.synced === true;
          } catch (error) {
            console.error('Error checking indexer health:', error);
            return false;
          }
        }
      });
    }
  }

  async runHealthChecks(): Promise<HealthCheckResult[]> {
    const results: HealthCheckResult[] = [];
    
    console.log(`[${new Date().toISOString()}] Running health checks...`);
    
    for (const check of this.checks) {
      try {
        const success = await check.check();
        const result: HealthCheckResult = {
          name: check.name,
          success,
          timestamp: Date.now()
        };
        
        if (!success) {
          result.error = `Check failed: ${check.name}`;
          console.error(`❌ ${check.name}: FAILED`);
          
          // Send alert if critical and not in cooldown
          if (check.critical && this.shouldSendAlert(check.name)) {
            await this.sendAlert([result]);
            this.updateAlertTime(check.name);
          }
        } else {
          console.log(`✅ ${check.name}: OK`);
        }
        
        results.push(result);
      } catch (error) {
        const result: HealthCheckResult = {
          name: check.name,
          success: false,
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: Date.now()
        };
        results.push(result);
        console.error(`❌ ${check.name}: ERROR - ${result.error}`);
      }
    }
    
    // Send summary alert if multiple critical failures
    const criticalFailures = results.filter((r, i) => 
      !r.success && this.checks[i].critical
    );
    
    if (criticalFailures.length >= 2) {
      await this.sendAlert(criticalFailures, true);
    }
    
    return results;
  }

  private shouldSendAlert(checkName: string): boolean {
    const lastAlert = this.lastAlertTime.get(checkName);
    if (!lastAlert) return true;
    return Date.now() - lastAlert > this.alertCooldown;
  }

  private updateAlertTime(checkName: string) {
    this.lastAlertTime.set(checkName, Date.now());
  }

  private async sendAlert(failures: HealthCheckResult[], isMultiple = false) {
    if (!this.config.alertWebhook) {
      console.log('Alert webhook not configured, skipping alert');
      return;
    }

    const title = isMultiple 
      ? '🚨 Multiple Critical Health Check Failures' 
      : `⚠️ Health Check Failed: ${failures[0].name}`;
    
    const message = {
      content: title,
      embeds: [{
        title: 'Health Monitor Alert',
        color: 0xff0000,
        fields: failures.map(f => ({
          name: f.name,
          value: f.error || 'Check failed',
          inline: false
        })),
        timestamp: new Date().toISOString(),
        footer: {
          text: 'Multi-Collateral BTC Vault Monitor'
        }
      }]
    };

    try {
      await axios.post(this.config.alertWebhook, message);
      console.log('Alert sent successfully');
    } catch (error) {
      console.error('Failed to send alert:', error);
    }
  }

  async start() {
    console.log('🚀 Starting health monitor...');
    console.log(`Check interval: ${this.config.checkInterval / 1000} seconds`);
    console.log(`Monitoring ${this.checks.length} health checks`);
    
    // Run initial check
    await this.runHealthChecks();
    
    // Set up interval
    setInterval(async () => {
      await this.runHealthChecks();
    }, this.config.checkInterval);
  }

  // Graceful shutdown
  stop() {
    console.log('Stopping health monitor...');
    process.exit(0);
  }
}

// Main execution
async function main() {
  const config: MonitorConfig = {
    rpcUrl: process.env.RPC_URL || 'https://base-sepolia.g.alchemy.com/v2/YOUR_KEY',
    alertWebhook: process.env.DISCORD_WEBHOOK || process.env.SLACK_WEBHOOK,
    vaultAddress: process.env.VAULT_ADDRESS || '0x73E27097221d4d9D5893a83350dC7A967b46fab7',
    queueAddress: process.env.QUEUE_ADDRESS || '0x22BC73098CE1Ba2CaE5431fb32051cB4fc0F9C52',
    strategyAddress: process.env.STRATEGY_ADDRESS || '0x740907524EbD6A481a81cE76B5115A4cDDb80099',
    priceOracleAddress: process.env.PRICE_ORACLE_ADDRESS || '0xDB4479A2360E118CCbD99B88e82522813BDE48f5',
    indexerUrl: process.env.INDEXER_URL || 'http://localhost:42069',
    checkInterval: parseInt(process.env.CHECK_INTERVAL || '300000') // Default 5 minutes
  };

  const monitor = new HealthMonitor(config);
  
  // Handle graceful shutdown
  process.on('SIGINT', () => monitor.stop());
  process.on('SIGTERM', () => monitor.stop());
  
  // Start monitoring
  await monitor.start();
}

// Run if executed directly
if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { HealthMonitor, MonitorConfig, HealthCheckResult };