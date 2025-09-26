#!/usr/bin/env node

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Load configuration
const config = {
  rpcUrl: process.env.BASE_RPC_URL || 'https://base-sepolia.g.alchemy.com/v2/YOUR_KEY',
  contracts: {
    strategy: process.env.STRATEGY_ADDRESS || '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
    token: process.env.TOKEN_ADDRESS || '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
    sovaBTC: process.env.SOVABTC_ADDRESS || '0x9901BDc36A2fd60aF17CA28c960E1fF2f968E426'
  },
  thresholds: {
    minLiquidity: ethers.parseUnits('10', 8), // 10 BTC minimum
    maxPriceDeviation: 500, // 5% max deviation
    minHealthScore: 80, // Minimum health score
    maxPendingWithdrawals: 100 // Maximum pending withdrawals
  },
  alertWebhook: process.env.ALERT_WEBHOOK_URL
};

// Load ABIs
const strategyABI = [
  'function availableLiquidity() view returns (uint256)',
  'function nav() view returns (uint256)',
  'function totalAssets() view returns (uint256)',
  'function pendingWithdrawals(address) view returns (uint256)',
  'function isSupportedCollateral(address) view returns (bool)',
  'event LiquidityAdded(uint256 amount)',
  'event LiquidityRemoved(uint256 amount)',
  'event WithdrawalRequested(address indexed user, uint256 shares)',
  'event WithdrawalApproved(address indexed user, uint256 shares)',
  'event WithdrawalCompleted(address indexed user, uint256 assets)'
];

const tokenABI = [
  'function totalSupply() view returns (uint256)',
  'function totalAssets() view returns (uint256)',
  'function convertToAssets(uint256 shares) view returns (uint256)',
  'function maxWithdraw(address owner) view returns (uint256)',
  'function maxRedeem(address owner) view returns (uint256)'
];

class HealthMonitor {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.strategy = new ethers.Contract(config.contracts.strategy, strategyABI, this.provider);
    this.token = new ethers.Contract(config.contracts.token, tokenABI, this.provider);
    this.healthMetrics = {};
    this.alerts = [];
  }

  async checkLiquidity() {
    try {
      const liquidity = await this.strategy.availableLiquidity();
      const liquidityFormatted = ethers.formatUnits(liquidity, 8);
      
      this.healthMetrics.liquidity = {
        value: liquidity,
        formatted: `${liquidityFormatted} BTC`,
        healthy: liquidity >= config.thresholds.minLiquidity,
        timestamp: Date.now()
      };

      if (liquidity < config.thresholds.minLiquidity) {
        this.alerts.push({
          severity: 'CRITICAL',
          message: `Low liquidity detected: ${liquidityFormatted} BTC`,
          metric: 'liquidity',
          value: liquidityFormatted
        });
      }

      console.log(`✓ Liquidity: ${liquidityFormatted} BTC`);
      return liquidity;
    } catch (error) {
      console.error('❌ Failed to check liquidity:', error.message);
      this.healthMetrics.liquidity = { error: error.message };
      return 0n;
    }
  }

  async checkNAV() {
    try {
      const nav = await this.strategy.nav();
      const totalAssets = await this.strategy.totalAssets();
      const navFormatted = ethers.formatUnits(nav, 8);
      const assetsFormatted = ethers.formatUnits(totalAssets, 8);
      
      const deviation = totalAssets > 0n 
        ? Number((nav - totalAssets) * 10000n / totalAssets) / 100
        : 0;

      this.healthMetrics.nav = {
        nav: navFormatted,
        totalAssets: assetsFormatted,
        deviation: `${deviation}%`,
        healthy: Math.abs(deviation) <= 5,
        timestamp: Date.now()
      };

      if (Math.abs(deviation) > 5) {
        this.alerts.push({
          severity: 'WARNING',
          message: `NAV deviation detected: ${deviation}%`,
          metric: 'nav_deviation',
          value: deviation
        });
      }

      console.log(`✓ NAV: ${navFormatted} BTC (Deviation: ${deviation}%)`);
      return nav;
    } catch (error) {
      console.error('❌ Failed to check NAV:', error.message);
      this.healthMetrics.nav = { error: error.message };
      return 0n;
    }
  }

  async checkSharePrice() {
    try {
      const totalSupply = await this.token.totalSupply();
      const totalAssets = await this.token.totalAssets();
      
      const sharePrice = totalSupply > 0n
        ? (totalAssets * ethers.parseUnits('1', 18)) / totalSupply
        : ethers.parseUnits('1', 18);
      
      const sharePriceFormatted = ethers.formatUnits(sharePrice, 18);
      
      this.healthMetrics.sharePrice = {
        value: sharePriceFormatted,
        totalSupply: ethers.formatUnits(totalSupply, 18),
        totalAssets: ethers.formatUnits(totalAssets, 8),
        healthy: true,
        timestamp: Date.now()
      };

      console.log(`✓ Share Price: ${sharePriceFormatted}`);
      return sharePrice;
    } catch (error) {
      console.error('❌ Failed to check share price:', error.message);
      this.healthMetrics.sharePrice = { error: error.message };
      return 0n;
    }
  }

  async checkRecentEvents() {
    try {
      const currentBlock = await this.provider.getBlockNumber();
      const fromBlock = currentBlock - 1000; // Last ~1000 blocks

      // Check for liquidity events
      const liquidityAddedFilter = this.strategy.filters.LiquidityAdded();
      const liquidityRemovedFilter = this.strategy.filters.LiquidityRemoved();
      
      const addedEvents = await this.strategy.queryFilter(liquidityAddedFilter, fromBlock);
      const removedEvents = await this.strategy.queryFilter(liquidityRemovedFilter, fromBlock);
      
      // Check for withdrawal events
      const withdrawalRequestedFilter = this.strategy.filters.WithdrawalRequested();
      const withdrawalApprovedFilter = this.strategy.filters.WithdrawalApproved();
      const withdrawalCompletedFilter = this.strategy.filters.WithdrawalCompleted();
      
      const requestedEvents = await this.strategy.queryFilter(withdrawalRequestedFilter, fromBlock);
      const approvedEvents = await this.strategy.queryFilter(withdrawalApprovedFilter, fromBlock);
      const completedEvents = await this.strategy.queryFilter(withdrawalCompletedFilter, fromBlock);

      this.healthMetrics.recentActivity = {
        liquidityAdded: addedEvents.length,
        liquidityRemoved: removedEvents.length,
        withdrawalsRequested: requestedEvents.length,
        withdrawalsApproved: approvedEvents.length,
        withdrawalsCompleted: completedEvents.length,
        blockRange: `${fromBlock} - ${currentBlock}`,
        timestamp: Date.now()
      };

      console.log(`✓ Recent Activity (last 1000 blocks):`);
      console.log(`  - Liquidity Added: ${addedEvents.length}`);
      console.log(`  - Liquidity Removed: ${removedEvents.length}`);
      console.log(`  - Withdrawals Requested: ${requestedEvents.length}`);
      console.log(`  - Withdrawals Approved: ${approvedEvents.length}`);
      console.log(`  - Withdrawals Completed: ${completedEvents.length}`);

      // Alert on unusual activity
      if (removedEvents.length > 10) {
        this.alerts.push({
          severity: 'WARNING',
          message: `High liquidity removal activity: ${removedEvents.length} events`,
          metric: 'liquidity_removal',
          value: removedEvents.length
        });
      }

      if (requestedEvents.length - completedEvents.length > config.thresholds.maxPendingWithdrawals) {
        this.alerts.push({
          severity: 'WARNING',
          message: `High pending withdrawals: ${requestedEvents.length - completedEvents.length}`,
          metric: 'pending_withdrawals',
          value: requestedEvents.length - completedEvents.length
        });
      }

    } catch (error) {
      console.error('❌ Failed to check recent events:', error.message);
      this.healthMetrics.recentActivity = { error: error.message };
    }
  }

  async checkCollaterals() {
    try {
      const collaterals = [
        { address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', name: 'wBTC' },
        { address: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802', name: 'tBTC' },
        { address: '0x9901BDc36A2fd60aF17CA28c960E1fF2f968E426', name: 'sovaBTC' }
      ];

      const results = [];
      for (const collateral of collaterals) {
        const isSupported = await this.strategy.isSupportedCollateral(collateral.address);
        results.push({
          name: collateral.name,
          address: collateral.address,
          supported: isSupported
        });
      }

      this.healthMetrics.collaterals = {
        supported: results.filter(c => c.supported).map(c => c.name),
        total: results.length,
        timestamp: Date.now()
      };

      console.log(`✓ Supported Collaterals: ${results.filter(c => c.supported).map(c => c.name).join(', ')}`);
      
    } catch (error) {
      console.error('❌ Failed to check collaterals:', error.message);
      this.healthMetrics.collaterals = { error: error.message };
    }
  }

  calculateHealthScore() {
    let score = 100;
    const factors = [];

    // Liquidity factor (40% weight)
    if (this.healthMetrics.liquidity?.healthy === false) {
      score -= 40;
      factors.push('Low liquidity (-40)');
    }

    // NAV deviation factor (20% weight)
    if (this.healthMetrics.nav?.healthy === false) {
      score -= 20;
      factors.push('NAV deviation (-20)');
    }

    // Activity factor (20% weight)
    const activity = this.healthMetrics.recentActivity;
    if (activity) {
      const pendingWithdrawals = (activity.withdrawalsRequested || 0) - (activity.withdrawalsCompleted || 0);
      if (pendingWithdrawals > config.thresholds.maxPendingWithdrawals) {
        score -= 20;
        factors.push('High pending withdrawals (-20)');
      }
    }

    // Error factor (20% weight)
    const hasErrors = Object.values(this.healthMetrics).some(metric => metric.error);
    if (hasErrors) {
      score -= 20;
      factors.push('Monitoring errors (-20)');
    }

    this.healthMetrics.healthScore = {
      score: Math.max(0, score),
      factors,
      healthy: score >= config.thresholds.minHealthScore,
      timestamp: Date.now()
    };

    if (score < config.thresholds.minHealthScore) {
      this.alerts.push({
        severity: 'CRITICAL',
        message: `Low health score: ${score}/100`,
        metric: 'health_score',
        value: score,
        factors
      });
    }

    console.log(`\n📊 Health Score: ${score}/100`);
    if (factors.length > 0) {
      console.log(`   Factors: ${factors.join(', ')}`);
    }

    return score;
  }

  async sendAlerts() {
    if (this.alerts.length === 0) {
      console.log('\n✅ No alerts to send');
      return;
    }

    console.log(`\n⚠️  ${this.alerts.length} alert(s) detected:`);
    
    for (const alert of this.alerts) {
      console.log(`   [${alert.severity}] ${alert.message}`);
    }

    // Send to webhook if configured
    if (config.alertWebhook) {
      try {
        const response = await fetch(config.alertWebhook, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            alerts: this.alerts,
            metrics: this.healthMetrics,
            timestamp: Date.now()
          })
        });

        if (response.ok) {
          console.log('   ✓ Alerts sent to webhook');
        } else {
          console.log('   ❌ Failed to send alerts to webhook');
        }
      } catch (error) {
        console.error('   ❌ Error sending alerts:', error.message);
      }
    }
  }

  saveMetrics() {
    const outputPath = path.join(__dirname, 'health-metrics.json');
    const output = {
      timestamp: Date.now(),
      date: new Date().toISOString(),
      network: config.rpcUrl.includes('sepolia') ? 'base-sepolia' : 'base-mainnet',
      contracts: config.contracts,
      metrics: this.healthMetrics,
      alerts: this.alerts
    };

    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
    console.log(`\n📁 Metrics saved to ${outputPath}`);
  }

  async run() {
    console.log('====================================');
    console.log('BTC Vault Health Check');
    console.log('====================================');
    console.log(`Time: ${new Date().toISOString()}`);
    console.log(`Network: ${config.rpcUrl.includes('sepolia') ? 'Base Sepolia' : 'Base Mainnet'}`);
    console.log(`Strategy: ${config.contracts.strategy}`);
    console.log(`Token: ${config.contracts.token}`);
    console.log('------------------------------------\n');

    // Run all health checks
    await this.checkLiquidity();
    await this.checkNAV();
    await this.checkSharePrice();
    await this.checkCollaterals();
    await this.checkRecentEvents();
    
    // Calculate overall health
    const healthScore = this.calculateHealthScore();
    
    // Send alerts if needed
    await this.sendAlerts();
    
    // Save metrics to file
    this.saveMetrics();

    console.log('\n====================================');
    console.log(healthScore >= 80 ? '✅ System Healthy' : '⚠️  System Needs Attention');
    console.log('====================================\n');

    return {
      healthy: healthScore >= config.thresholds.minHealthScore,
      score: healthScore,
      metrics: this.healthMetrics,
      alerts: this.alerts
    };
  }
}

// Run health check if executed directly
if (require.main === module) {
  const monitor = new HealthMonitor();
  monitor.run()
    .then(result => {
      process.exit(result.healthy ? 0 : 1);
    })
    .catch(error => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

module.exports = HealthMonitor;