'use client';

import { useAccount, useReadContract } from 'wagmi';
import { formatUnits } from 'viem';
import { useNetworkContracts } from '@/hooks/useNetworkContracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '@/lib/abis';
import { useVaultStats } from '@/hooks/useVaultMetrics';
import { useRecentDeposits, useRecentWithdrawals } from '@/hooks/useTransactionHistory';
import { GlassCard } from '@/components/GlassCard';
import TransactionHistory from '@/components/TransactionHistory';
import SchedulerStatus from '@/components/SchedulerStatus';
import { ChainSelector } from '@/components/ChainSelector';
import { CrossChainMetrics } from '@/components/CrossChainMetrics';
import { 
  TrendingUp, 
  Users, 
  Coins, 
  Activity,
  ArrowUp,
  ArrowDown,
  DollarSign,
  BarChart3,
  PieChart,
  Clock,
  RefreshCwIcon,
  Layers
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { useState } from 'react';

// Mock data for charts (will be replaced with real data from GraphQL)
const mockTVLData = [
  { date: '1 Jan', value: 100 },
  { date: '8 Jan', value: 120 },
  { date: '15 Jan', value: 115 },
  { date: '22 Jan', value: 140 },
  { date: '29 Jan', value: 135 },
  { date: '5 Feb', value: 160 },
  { date: '12 Feb', value: 175 },
];

const mockCollateralDistribution = [
  { name: 'sovaBTC', value: 45, color: 'bg-orange-500' },
  { name: 'WBTC', value: 30, color: 'bg-blue-500' },
  { name: 'tBTC', value: 25, color: 'bg-mint-500' },
];

export default function DashboardPage() {
  const { address } = useAccount();
  const { btcVaultStrategy, btcVaultToken, isSupported } = useNetworkContracts();
  const [showScheduler, setShowScheduler] = useState(false);
  const [showCrossChain, setShowCrossChain] = useState(false);
  const [selectedChain, setSelectedChain] = useState<number | null>(null);

  // Get data from GraphQL
  const { stats: vaultStats, loading: statsLoading } = useVaultStats();
  const { deposits, loading: depositsLoading } = useRecentDeposits(5);
  const { withdrawals, loading: withdrawalsLoading } = useRecentWithdrawals(5);

  // Read vault data from contracts
  const { data: totalAssets } = useReadContract(
    isSupported ? {
      address: btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'totalAssets',
    } : undefined
  );

  const { data: totalSupply } = useReadContract(
    isSupported ? {
      address: btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'totalSupply',
    } : undefined
  );

  const { data: availableLiquidity } = useReadContract(
    isSupported ? {
      address: btcVaultStrategy as `0x${string}`,
      abi: BTC_VAULT_STRATEGY_ABI,
      functionName: 'availableLiquidity',
    } : undefined
  );

  // User data
  const { data: userBalance } = useReadContract(
    isSupported && address ? {
      address: btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'balanceOf',
      args: [address],
    } : undefined
  );

  // Use indexed data if available, fallback to contract data
  const tvl = vaultStats?.totalAssets 
    ? Number(formatUnits(BigInt(vaultStats.totalAssets), 8))
    : totalAssets 
    ? Number(formatUnits(totalAssets, 8)) 
    : 0;

  const shares = vaultStats?.totalSupply
    ? Number(formatUnits(BigInt(vaultStats.totalSupply), 18))
    : totalSupply 
    ? Number(formatUnits(totalSupply, 18)) 
    : 0;

  const liquidity = availableLiquidity ? Number(formatUnits(availableLiquidity, 8)) : 0;
  const sharePrice = vaultStats?.sharePrice 
    ? Number(formatUnits(BigInt(vaultStats.sharePrice), 18))
    : shares > 0 ? tvl / shares : 1;
  const userShares = userBalance ? Number(formatUnits(userBalance, 18)) : 0;
  const userValue = userShares * sharePrice;

  // Calculate flows from indexed data
  const totalDepositsAmount = vaultStats?.totalDeposits 
    ? Number(formatUnits(BigInt(vaultStats.totalDeposits), 8))
    : 0;
  const totalWithdrawalsAmount = vaultStats?.totalWithdrawals
    ? Number(formatUnits(BigInt(vaultStats.totalWithdrawals), 8))
    : 0;
  const netFlow = totalDepositsAmount - totalWithdrawalsAmount;

  // Calculate mock APY (in production, this would be calculated from historical data)
  const apy = 12.5;
  const dailyYield = apy / 365;

  // Combine recent transactions
  const recentTransactions = [...(deposits || []), ...(withdrawals || [])]
    .map(tx => ({
      type: 'depositor' in tx ? 'deposit' : 'withdrawal',
      user: tx.depositor || tx.withdrawer,
      amount: tx.amount,
      timestamp: tx.timestamp,
      transactionHash: tx.transactionHash, // Already mapped in useTransactionHistory hook
    }))
    .sort((a, b) => b.timestamp - a.timestamp)
    .slice(0, 5);

  return (
    <main className="container mx-auto px-4 sm:px-6 py-8 sm:py-12">
      <div className="mb-8 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-4xl font-bold text-white mb-2">Dashboard</h1>
          <p className="text-white/60">Monitor vault performance and your positions</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <ChainSelector showAll onChainSelect={setSelectedChain} />
          <button
            onClick={() => setShowCrossChain(!showCrossChain)}
            className="px-4 py-2 bg-mint-500/20 hover:bg-mint-500/30 text-mint-400 rounded-lg flex items-center gap-2 transition-colors"
          >
            <Layers className="w-4 h-4" />
            {showCrossChain ? 'Hide' : 'Show'} Cross-Chain
          </button>
          <button
            onClick={() => setShowScheduler(!showScheduler)}
            className="px-4 py-2 bg-mint-500/20 hover:bg-mint-500/30 text-mint-400 rounded-lg flex items-center gap-2 transition-colors"
          >
            <Activity className="w-4 h-4" />
            {showScheduler ? 'Hide' : 'Show'} Services
          </button>
        </div>
      </div>

      {/* Service Status Panel */}
      {showScheduler && (
        <div className="mb-8">
          <SchedulerStatus />
        </div>
      )}

      {/* Cross-Chain Metrics Panel */}
      {showCrossChain && (
        <div className="mb-8">
          <CrossChainMetrics />
        </div>
      )}

      {/* Key Metrics with Real Data */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Total Value Locked</p>
              <p className="text-2xl font-bold text-white">
                {statsLoading ? (
                  <span className="animate-pulse">...</span>
                ) : (
                  tvl.toFixed(4)
                )}
              </p>
              {netFlow !== 0 && (
                <div className="flex items-center gap-1 mt-1">
                  {netFlow > 0 ? (
                    <>
                      <ArrowUp className="w-3 h-3 text-green-400" />
                      <p className="text-green-400 text-xs">+{netFlow.toFixed(4)} net inflow</p>
                    </>
                  ) : (
                    <>
                      <ArrowDown className="w-3 h-3 text-red-400" />
                      <p className="text-red-400 text-xs">{netFlow.toFixed(4)} net outflow</p>
                    </>
                  )}
                </div>
              )}
            </div>
            <TrendingUp className="w-8 h-8 text-green-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Current APY</p>
              <p className="text-2xl font-bold text-white">{apy.toFixed(2)}%</p>
              <p className="text-white/40 text-xs">{dailyYield.toFixed(3)}% daily</p>
            </div>
            <DollarSign className="w-8 h-8 text-yellow-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Total Transactions</p>
              <p className="text-2xl font-bold text-white">
                {depositsLoading || withdrawalsLoading ? (
                  <span className="animate-pulse">...</span>
                ) : (
                  (deposits?.length || 0) + (withdrawals?.length || 0)
                )}
              </p>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-green-400 text-xs">{deposits?.length || 0} deposits</span>
                <span className="text-white/40">|</span>
                <span className="text-red-400 text-xs">{withdrawals?.length || 0} withdrawals</span>
              </div>
            </div>
            <Users className="w-8 h-8 text-blue-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Share Price</p>
              <p className="text-2xl font-bold text-white">
                {statsLoading ? (
                  <span className="animate-pulse">...</span>
                ) : (
                  sharePrice.toFixed(6)
                )}
              </p>
              <p className="text-white/40 text-xs">BTC per share</p>
            </div>
            <Coins className="w-8 h-8 text-mint-400" />
          </div>
        </GlassCard>
      </div>

      {/* User Position */}
      {address && userShares > 0 && (
        <GlassCard className="mb-8">
          <h3 className="text-lg font-semibold text-white mb-4">Your Position</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div>
              <p className="text-white/60 text-sm">Your Shares</p>
              <p className="text-xl font-bold text-white">{userShares.toFixed(4)}</p>
              <p className="text-white/40 text-xs">btcVault</p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Current Value</p>
              <p className="text-xl font-bold text-white">{userValue.toFixed(6)}</p>
              <p className="text-white/40 text-xs">BTC</p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Daily Earnings</p>
              <p className="text-xl font-bold text-green-400">
                +{(userValue * dailyYield / 100).toFixed(8)}
              </p>
              <p className="text-white/40 text-xs">BTC per day</p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Yearly Projection</p>
              <p className="text-xl font-bold text-green-400">
                +{(userValue * apy / 100).toFixed(6)}
              </p>
              <p className="text-white/40 text-xs">BTC per year</p>
            </div>
          </div>
        </GlassCard>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        {/* TVL Chart */}
        <GlassCard>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-white">Total Value Locked</h3>
            <BarChart3 className="w-5 h-5 text-white/40" />
          </div>
          <div className="h-64 flex items-end justify-between gap-2">
            {mockTVLData.map((item, index) => (
              <div key={index} className="flex-1 flex flex-col items-center gap-2">
                <div 
                  className="w-full bg-gradient-to-t from-blue-500 to-mint-500 rounded-t-lg hover:opacity-80 transition-opacity relative group"
                  style={{ height: `${(item.value / 175) * 100}%` }}
                >
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-mint-500 px-2 py-1 rounded text-xs text-white opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                    {item.value} BTC
                  </div>
                </div>
                <span className="text-xs text-white/40">{item.date}</span>
              </div>
            ))}
          </div>
        </GlassCard>

        {/* Collateral Distribution */}
        <GlassCard>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-white">Collateral Distribution</h3>
            <PieChart className="w-5 h-5 text-white/40" />
          </div>
          <div className="flex items-center justify-center h-48">
            <div className="relative w-48 h-48">
              {/* Pie chart visualization */}
              <svg className="w-full h-full transform -rotate-90">
                {mockCollateralDistribution.reduce((acc, item, index) => {
                  const startAngle = acc;
                  const angle = (item.value / 100) * 360;
                  const largeArcFlag = angle > 180 ? 1 : 0;
                  const x1 = 96 + 80 * Math.cos((startAngle * Math.PI) / 180);
                  const y1 = 96 + 80 * Math.sin((startAngle * Math.PI) / 180);
                  const x2 = 96 + 80 * Math.cos(((startAngle + angle) * Math.PI) / 180);
                  const y2 = 96 + 80 * Math.sin(((startAngle + angle) * Math.PI) / 180);
                  
                  return acc + angle;
                }, 0) && mockCollateralDistribution.map((item, index) => {
                  const startAngle = mockCollateralDistribution
                    .slice(0, index)
                    .reduce((sum, i) => sum + (i.value / 100) * 360, 0);
                  const angle = (item.value / 100) * 360;
                  
                  return (
                    <circle
                      key={index}
                      cx="96"
                      cy="96"
                      r="80"
                      fill="none"
                      stroke={
                        item.color === 'bg-orange-500' ? '#f97316' :
                        item.color === 'bg-blue-500' ? '#3b82f6' :
                        '#a855f7'
                      }
                      strokeWidth="40"
                      strokeDasharray={`${(angle / 360) * 502.65} 502.65`}
                      strokeDashoffset={-startAngle / 360 * 502.65}
                      className="transition-all duration-300 hover:opacity-80"
                    />
                  );
                })}
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="text-center">
                  <p className="text-2xl font-bold text-white">{tvl.toFixed(2)}</p>
                  <p className="text-xs text-white/60">Total BTC</p>
                </div>
              </div>
            </div>
          </div>
          <div className="mt-4 space-y-2">
            {mockCollateralDistribution.map((item) => (
              <div key={item.name} className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={cn('w-3 h-3 rounded-full', item.color)} />
                  <span className="text-sm text-white/80">{item.name}</span>
                </div>
                <span className="text-sm text-white/60">{item.value}%</span>
              </div>
            ))}
          </div>
        </GlassCard>
      </div>

      {/* Transaction History Component with Real Data */}
      <div className="mb-8">
        <TransactionHistory limit={10} showUserFilter={true} />
      </div>

      {/* Quick Stats from Indexed Data */}
      {vaultStats && (
        <GlassCard>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-white">Indexed Blockchain Data</h3>
            <RefreshCwIcon className={`w-5 h-5 text-white/40 ${statsLoading ? 'animate-spin' : ''}`} />
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-white/60 text-sm">Total Deposits</p>
              <p className="text-lg font-semibold text-green-400">
                {totalDepositsAmount.toFixed(4)} BTC
              </p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Total Withdrawals</p>
              <p className="text-lg font-semibold text-red-400">
                {totalWithdrawalsAmount.toFixed(4)} BTC
              </p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Net Flow</p>
              <p className={`text-lg font-semibold ${netFlow >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                {netFlow >= 0 ? '+' : ''}{netFlow.toFixed(4)} BTC
              </p>
            </div>
            <div>
              <p className="text-white/60 text-sm">Available Liquidity</p>
              <p className="text-lg font-semibold text-blue-400">
                {liquidity.toFixed(4)} sovaBTC
              </p>
            </div>
          </div>
        </GlassCard>
      )}
    </main>
  );
}