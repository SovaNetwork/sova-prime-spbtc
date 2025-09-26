#!/usr/bin/env node

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Configuration
const config = {
  rpcUrl: process.env.BASE_RPC_URL || 'https://base-sepolia.g.alchemy.com/v2/YOUR_KEY',
  contracts: {
    strategy: process.env.STRATEGY_ADDRESS || '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
    token: process.env.TOKEN_ADDRESS || '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
    sovaBTC: process.env.SOVABTC_ADDRESS || '0x9901BDc36A2fd60aF17CA28c960E1fF2f968E426'
  },
  collectionInterval: 60000, // 1 minute
  historySize: 1440, // Keep 24 hours of minute data
  outputDir: path.join(__dirname, 'metrics-data')
};

// ABIs
const strategyABI = [
  'function availableLiquidity() view returns (uint256)',
  'function nav() view returns (uint256)',
  'function totalAssets() view returns (uint256)',
  'function pendingWithdrawals(address) view returns (uint256)',
  'event CollateralDeposited(address indexed depositor, address indexed collateral, uint256 amount, uint256 shares)',
  'event WithdrawalRequested(address indexed user, uint256 shares)',
  'event WithdrawalApproved(address indexed user, uint256 shares)',
  'event WithdrawalCompleted(address indexed user, uint256 assets)',
  'event LiquidityAdded(uint256 amount)',
  'event LiquidityRemoved(uint256 amount)'
];

const tokenABI = [
  'function totalSupply() view returns (uint256)',
  'function totalAssets() view returns (uint256)',
  'function convertToAssets(uint256 shares) view returns (uint256)',
  'function balanceOf(address) view returns (uint256)'
];

class MetricsCollector {
  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.strategy = new ethers.Contract(config.contracts.strategy, strategyABI, this.provider);
    this.token = new ethers.Contract(config.contracts.token, tokenABI, this.provider);
    this.metricsHistory = [];
    this.eventCache = new Map();
    
    // Ensure output directory exists
    if (!fs.existsSync(config.outputDir)) {
      fs.mkdirSync(config.outputDir, { recursive: true });
    }
    
    // Load existing history if available
    this.loadHistory();
  }

  loadHistory() {
    const historyFile = path.join(config.outputDir, 'metrics-history.json');
    if (fs.existsSync(historyFile)) {
      try {
        const data = fs.readFileSync(historyFile, 'utf8');
        this.metricsHistory = JSON.parse(data);
        console.log(`📂 Loaded ${this.metricsHistory.length} historical data points`);
      } catch (error) {
        console.error('Failed to load history:', error.message);
        this.metricsHistory = [];
      }
    }
  }

  saveHistory() {
    const historyFile = path.join(config.outputDir, 'metrics-history.json');
    
    // Trim history to configured size
    if (this.metricsHistory.length > config.historySize) {
      this.metricsHistory = this.metricsHistory.slice(-config.historySize);
    }
    
    fs.writeFileSync(historyFile, JSON.stringify(this.metricsHistory, null, 2));
  }

  async collectMetrics() {
    const timestamp = Date.now();
    const metrics = {
      timestamp,
      date: new Date(timestamp).toISOString(),
      block: await this.provider.getBlockNumber()
    };

    try {
      // Collect on-chain metrics
      const [liquidity, nav, totalAssets, totalSupply, tokenTotalAssets] = await Promise.all([
        this.strategy.availableLiquidity(),
        this.strategy.nav(),
        this.strategy.totalAssets(),
        this.token.totalSupply(),
        this.token.totalAssets()
      ]);

      metrics.liquidity = {
        available: ethers.formatUnits(liquidity, 8),
        raw: liquidity.toString()
      };

      metrics.nav = {
        value: ethers.formatUnits(nav, 8),
        raw: nav.toString()
      };

      metrics.vault = {
        totalAssets: ethers.formatUnits(totalAssets, 8),
        totalSupply: ethers.formatUnits(totalSupply, 18),
        sharePrice: totalSupply > 0n 
          ? Number((tokenTotalAssets * ethers.parseUnits('1', 18)) / totalSupply) / 1e18
          : 1
      };

      // Calculate TVL
      metrics.tvl = {
        btc: ethers.formatUnits(totalAssets, 8),
        usd: 0 // Would need price feed for USD conversion
      };

      // Collect event metrics
      metrics.events = await this.collectEventMetrics(metrics.block);

      // Calculate rates
      if (this.metricsHistory.length > 0) {
        const prevMetrics = this.metricsHistory[this.metricsHistory.length - 1];
        metrics.rates = this.calculateRates(metrics, prevMetrics);
      }

      // Calculate statistics
      metrics.stats = this.calculateStatistics();

      console.log(`📊 Metrics collected at block ${metrics.block}`);
      
    } catch (error) {
      console.error('Error collecting metrics:', error.message);
      metrics.error = error.message;
    }

    // Add to history
    this.metricsHistory.push(metrics);
    
    // Save to disk
    this.saveHistory();
    this.saveLatestMetrics(metrics);
    
    return metrics;
  }

  async collectEventMetrics(currentBlock) {
    const lookbackBlocks = 1000; // ~4 hours on Base
    const fromBlock = Math.max(0, currentBlock - lookbackBlocks);
    
    const events = {
      deposits: 0,
      withdrawalsRequested: 0,
      withdrawalsApproved: 0,
      withdrawalsCompleted: 0,
      liquidityAdded: 0,
      liquidityRemoved: 0,
      volume: {
        deposits: '0',
        withdrawals: '0'
      }
    };

    try {
      // Get deposit events
      const depositFilter = this.strategy.filters.CollateralDeposited();
      const depositEvents = await this.strategy.queryFilter(depositFilter, fromBlock, currentBlock);
      events.deposits = depositEvents.length;
      
      // Calculate deposit volume
      let depositVolume = 0n;
      for (const event of depositEvents) {
        depositVolume += event.args[2]; // amount argument
      }
      events.volume.deposits = ethers.formatUnits(depositVolume, 8);

      // Get withdrawal events
      const withdrawalRequestFilter = this.strategy.filters.WithdrawalRequested();
      const withdrawalApproveFilter = this.strategy.filters.WithdrawalApproved();
      const withdrawalCompleteFilter = this.strategy.filters.WithdrawalCompleted();
      
      const [requestEvents, approveEvents, completeEvents] = await Promise.all([
        this.strategy.queryFilter(withdrawalRequestFilter, fromBlock, currentBlock),
        this.strategy.queryFilter(withdrawalApproveFilter, fromBlock, currentBlock),
        this.strategy.queryFilter(withdrawalCompleteFilter, fromBlock, currentBlock)
      ]);
      
      events.withdrawalsRequested = requestEvents.length;
      events.withdrawalsApproved = approveEvents.length;
      events.withdrawalsCompleted = completeEvents.length;
      
      // Calculate withdrawal volume
      let withdrawalVolume = 0n;
      for (const event of completeEvents) {
        withdrawalVolume += event.args[1]; // assets argument
      }
      events.volume.withdrawals = ethers.formatUnits(withdrawalVolume, 8);

      // Get liquidity events
      const liquidityAddFilter = this.strategy.filters.LiquidityAdded();
      const liquidityRemoveFilter = this.strategy.filters.LiquidityRemoved();
      
      const [addEvents, removeEvents] = await Promise.all([
        this.strategy.queryFilter(liquidityAddFilter, fromBlock, currentBlock),
        this.strategy.queryFilter(liquidityRemoveFilter, fromBlock, currentBlock)
      ]);
      
      events.liquidityAdded = addEvents.length;
      events.liquidityRemoved = removeEvents.length;
      
    } catch (error) {
      console.error('Error collecting events:', error.message);
    }

    return events;
  }

  calculateRates(current, previous) {
    const timeDiff = (current.timestamp - previous.timestamp) / 1000; // seconds
    
    const rates = {
      depositRate: 0,
      withdrawalRate: 0,
      liquidityChangeRate: 0,
      tvlGrowthRate: 0
    };

    if (timeDiff > 0) {
      // Calculate deposit rate (deposits per hour)
      if (current.events && previous.events) {
        const depositDiff = current.events.deposits - previous.events.deposits;
        rates.depositRate = (depositDiff / timeDiff) * 3600;
        
        const withdrawalDiff = current.events.withdrawalsCompleted - previous.events.withdrawalsCompleted;
        rates.withdrawalRate = (withdrawalDiff / timeDiff) * 3600;
      }

      // Calculate liquidity change rate
      if (current.liquidity && previous.liquidity) {
        const liquidityChange = parseFloat(current.liquidity.available) - parseFloat(previous.liquidity.available);
        rates.liquidityChangeRate = (liquidityChange / timeDiff) * 3600; // BTC per hour
      }

      // Calculate TVL growth rate
      if (current.vault && previous.vault) {
        const tvlChange = parseFloat(current.vault.totalAssets) - parseFloat(previous.vault.totalAssets);
        const prevTvl = parseFloat(previous.vault.totalAssets);
        if (prevTvl > 0) {
          rates.tvlGrowthRate = ((tvlChange / prevTvl) / timeDiff) * 86400 * 100; // % per day
        }
      }
    }

    return rates;
  }

  calculateStatistics() {
    const stats = {
      hourly: {},
      daily: {},
      weekly: {}
    };

    const now = Date.now();
    const hour = 60 * 60 * 1000;
    const day = 24 * hour;
    const week = 7 * day;

    // Filter data by time periods
    const hourlyData = this.metricsHistory.filter(m => m.timestamp > now - hour);
    const dailyData = this.metricsHistory.filter(m => m.timestamp > now - day);
    const weeklyData = this.metricsHistory.filter(m => m.timestamp > now - week);

    // Calculate statistics for each period
    stats.hourly = this.calculatePeriodStats(hourlyData);
    stats.daily = this.calculatePeriodStats(dailyData);
    stats.weekly = this.calculatePeriodStats(weeklyData);

    return stats;
  }

  calculatePeriodStats(data) {
    if (data.length === 0) return null;

    const stats = {
      deposits: 0,
      withdrawals: 0,
      volume: { deposits: 0, withdrawals: 0 },
      avgLiquidity: 0,
      avgSharePrice: 0,
      tvlChange: 0
    };

    // Sum events
    for (const metric of data) {
      if (metric.events) {
        stats.deposits += metric.events.deposits;
        stats.withdrawals += metric.events.withdrawalsCompleted;
        stats.volume.deposits += parseFloat(metric.events.volume.deposits || 0);
        stats.volume.withdrawals += parseFloat(metric.events.volume.withdrawals || 0);
      }
      
      if (metric.liquidity) {
        stats.avgLiquidity += parseFloat(metric.liquidity.available);
      }
      
      if (metric.vault) {
        stats.avgSharePrice += metric.vault.sharePrice || 0;
      }
    }

    // Calculate averages
    stats.avgLiquidity /= data.length;
    stats.avgSharePrice /= data.length;

    // Calculate TVL change
    if (data.length > 1 && data[0].vault && data[data.length - 1].vault) {
      const startTvl = parseFloat(data[0].vault.totalAssets);
      const endTvl = parseFloat(data[data.length - 1].vault.totalAssets);
      stats.tvlChange = endTvl - startTvl;
      stats.tvlChangePercent = startTvl > 0 ? ((endTvl - startTvl) / startTvl) * 100 : 0;
    }

    return stats;
  }

  saveLatestMetrics(metrics) {
    const latestFile = path.join(config.outputDir, 'latest-metrics.json');
    fs.writeFileSync(latestFile, JSON.stringify(metrics, null, 2));
    
    // Also save a CSV for easy analysis
    this.appendToCSV(metrics);
  }

  appendToCSV(metrics) {
    const csvFile = path.join(config.outputDir, 'metrics.csv');
    const isNewFile = !fs.existsSync(csvFile);
    
    const row = [
      metrics.date,
      metrics.block,
      metrics.liquidity?.available || '',
      metrics.nav?.value || '',
      metrics.vault?.totalAssets || '',
      metrics.vault?.totalSupply || '',
      metrics.vault?.sharePrice || '',
      metrics.events?.deposits || 0,
      metrics.events?.withdrawalsCompleted || 0,
      metrics.events?.volume?.deposits || 0,
      metrics.events?.volume?.withdrawals || 0
    ];

    if (isNewFile) {
      const headers = [
        'Date',
        'Block',
        'Available Liquidity (BTC)',
        'NAV (BTC)',
        'Total Assets (BTC)',
        'Total Supply (Shares)',
        'Share Price',
        'Deposits (Count)',
        'Withdrawals (Count)',
        'Deposit Volume (BTC)',
        'Withdrawal Volume (BTC)'
      ];
      fs.writeFileSync(csvFile, headers.join(',') + '\n');
    }

    fs.appendFileSync(csvFile, row.join(',') + '\n');
  }

  generateReport() {
    const stats = this.calculateStatistics();
    const latest = this.metricsHistory[this.metricsHistory.length - 1];
    
    console.log('\n====================================');
    console.log('BTC Vault Metrics Report');
    console.log('====================================');
    console.log(`Generated: ${new Date().toISOString()}`);
    console.log(`Data Points: ${this.metricsHistory.length}`);
    console.log('------------------------------------\n');

    if (latest) {
      console.log('📈 Current Metrics:');
      console.log(`  Block: ${latest.block}`);
      console.log(`  Available Liquidity: ${latest.liquidity?.available || 'N/A'} BTC`);
      console.log(`  NAV: ${latest.nav?.value || 'N/A'} BTC`);
      console.log(`  Total Assets: ${latest.vault?.totalAssets || 'N/A'} BTC`);
      console.log(`  Share Price: ${latest.vault?.sharePrice?.toFixed(6) || 'N/A'}`);
      console.log('');
    }

    if (stats.hourly) {
      console.log('📊 Hourly Statistics:');
      console.log(`  Deposits: ${stats.hourly.deposits}`);
      console.log(`  Withdrawals: ${stats.hourly.withdrawals}`);
      console.log(`  Deposit Volume: ${stats.hourly.volume.deposits.toFixed(4)} BTC`);
      console.log(`  Withdrawal Volume: ${stats.hourly.volume.withdrawals.toFixed(4)} BTC`);
      console.log(`  Avg Liquidity: ${stats.hourly.avgLiquidity.toFixed(4)} BTC`);
      console.log(`  TVL Change: ${stats.hourly.tvlChange > 0 ? '+' : ''}${stats.hourly.tvlChange.toFixed(4)} BTC`);
      console.log('');
    }

    if (stats.daily) {
      console.log('📊 Daily Statistics:');
      console.log(`  Deposits: ${stats.daily.deposits}`);
      console.log(`  Withdrawals: ${stats.daily.withdrawals}`);
      console.log(`  Deposit Volume: ${stats.daily.volume.deposits.toFixed(4)} BTC`);
      console.log(`  Withdrawal Volume: ${stats.daily.volume.withdrawals.toFixed(4)} BTC`);
      console.log(`  Avg Liquidity: ${stats.daily.avgLiquidity.toFixed(4)} BTC`);
      console.log(`  TVL Change: ${stats.daily.tvlChange > 0 ? '+' : ''}${stats.daily.tvlChange.toFixed(4)} BTC (${stats.daily.tvlChangePercent?.toFixed(2)}%)`);
      console.log('');
    }

    console.log('📁 Output Files:');
    console.log(`  Latest: ${path.join(config.outputDir, 'latest-metrics.json')}`);
    console.log(`  History: ${path.join(config.outputDir, 'metrics-history.json')}`);
    console.log(`  CSV: ${path.join(config.outputDir, 'metrics.csv')}`);
    console.log('\n====================================\n');
  }

  async start() {
    console.log('🚀 Starting BTC Vault Metrics Collector');
    console.log(`📍 Network: ${config.rpcUrl.includes('sepolia') ? 'Base Sepolia' : 'Base Mainnet'}`);
    console.log(`⏱️  Collection Interval: ${config.collectionInterval / 1000} seconds`);
    console.log(`📊 History Size: ${config.historySize} data points\n`);

    // Collect initial metrics
    await this.collectMetrics();
    this.generateReport();

    // Set up interval collection
    setInterval(async () => {
      await this.collectMetrics();
      
      // Generate report every 10 collections
      if (this.metricsHistory.length % 10 === 0) {
        this.generateReport();
      }
    }, config.collectionInterval);

    console.log('✅ Metrics collection started. Press Ctrl+C to stop.\n');
  }
}

// Run collector if executed directly
if (require.main === module) {
  const collector = new MetricsCollector();
  
  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n\n🛑 Shutting down metrics collector...');
    collector.generateReport();
    process.exit(0);
  });

  collector.start().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = MetricsCollector;