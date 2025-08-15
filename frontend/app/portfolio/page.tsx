'use client';

import { useState } from 'react';
import { useAccount, useReadContract } from 'wagmi';
import { formatUnits } from 'viem';
import { useNetworkContracts } from '@/hooks/useNetworkContracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '@/lib/abis';
import { GlassCard } from '@/components/GlassCard';
import { 
  Wallet,
  TrendingUp,
  Calendar,
  Download,
  ArrowUpRight,
  ArrowDownRight,
  Clock,
  PieChart,
  DollarSign,
  Activity
} from 'lucide-react';
import { cn } from '@/lib/utils';

// Mock transaction history (in production, this would come from an indexer)
const mockTransactionHistory = [
  { 
    id: '1',
    type: 'deposit',
    amount: '0.5',
    shares: '0.4985',
    price: '1.003',
    timestamp: new Date('2024-02-10T14:30:00'),
    hash: '0x1234567890abcdef...'
  },
  { 
    id: '2',
    type: 'withdrawal',
    amount: '0.1',
    shares: '0.0995',
    price: '1.005',
    timestamp: new Date('2024-02-08T10:15:00'),
    hash: '0xabcdef1234567890...'
  },
  { 
    id: '3',
    type: 'deposit',
    amount: '0.25',
    shares: '0.2487',
    price: '1.004',
    timestamp: new Date('2024-02-05T16:45:00'),
    hash: '0xfedcba0987654321...'
  },
  { 
    id: '4',
    type: 'deposit',
    amount: '1.0',
    shares: '0.9975',
    price: '1.002',
    timestamp: new Date('2024-01-28T09:00:00'),
    hash: '0x567890abcdef1234...'
  },
];

// Mock performance data
const mockPerformanceData = [
  { month: 'Jan', value: 100, earnings: 0 },
  { month: 'Feb', value: 101.2, earnings: 1.2 },
  { month: 'Mar', value: 102.5, earnings: 2.5 },
  { month: 'Apr', value: 104.1, earnings: 4.1 },
  { month: 'May', value: 105.8, earnings: 5.8 },
  { month: 'Jun', value: 107.2, earnings: 7.2 },
];

export default function PortfolioPage() {
  const { address, isConnected } = useAccount();
  const { btcVaultStrategy, btcVaultToken, isSupported } = useNetworkContracts();
  const [selectedPeriod, setSelectedPeriod] = useState<'week' | 'month' | 'year'>('month');

  // Read user data
  const { data: userBalance } = useReadContract(
    isSupported && address ? {
      address: btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'balanceOf',
      args: [address],
    } : undefined
  );

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

  const tvl = totalAssets ? Number(formatUnits(totalAssets, 8)) : 0;
  const shares = totalSupply ? Number(formatUnits(totalSupply, 18)) : 0;
  const sharePrice = shares > 0 ? tvl / shares : 1;
  const userShares = userBalance ? Number(formatUnits(userBalance, 18)) : 0;
  const userValue = userShares * sharePrice;

  // Calculate portfolio metrics
  const totalDeposited = mockTransactionHistory
    .filter(tx => tx.type === 'deposit')
    .reduce((sum, tx) => sum + parseFloat(tx.amount), 0);
  
  const totalWithdrawn = mockTransactionHistory
    .filter(tx => tx.type === 'withdrawal')
    .reduce((sum, tx) => sum + parseFloat(tx.amount), 0);
  
  const netDeposited = totalDeposited - totalWithdrawn;
  const totalEarnings = userValue - netDeposited;
  const roi = netDeposited > 0 ? (totalEarnings / netDeposited) * 100 : 0;

  // Export to CSV
  const exportToCSV = () => {
    const headers = ['Date', 'Type', 'Amount (BTC)', 'Shares', 'Price', 'Transaction Hash'];
    const rows = mockTransactionHistory.map(tx => [
      tx.timestamp.toISOString(),
      tx.type,
      tx.amount,
      tx.shares,
      tx.price,
      tx.hash
    ]);
    
    const csvContent = [headers, ...rows]
      .map(row => row.join(','))
      .join('\n');
    
    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `portfolio-history-${Date.now()}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  if (!isConnected) {
    return (
      <main className="container mx-auto px-6 py-12">
        <GlassCard>
          <div className="text-center py-12">
            <Wallet className="w-16 h-16 text-white/40 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-white mb-2">Connect Your Wallet</h2>
            <p className="text-white/60">Please connect your wallet to view your portfolio</p>
          </div>
        </GlassCard>
      </main>
    );
  }

  return (
    <main className="container mx-auto px-6 py-12">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-white mb-2">Portfolio</h1>
        <p className="text-white/60">Track your vault performance and transaction history</p>
      </div>

      {/* Portfolio Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Current Value</p>
              <p className="text-2xl font-bold text-white">{userValue.toFixed(6)}</p>
              <p className="text-white/40 text-xs">BTC</p>
            </div>
            <Wallet className="w-8 h-8 text-blue-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Total Earnings</p>
              <p className="text-2xl font-bold text-green-400">
                {totalEarnings >= 0 ? '+' : ''}{totalEarnings.toFixed(6)}
              </p>
              <p className="text-white/40 text-xs">BTC</p>
            </div>
            <TrendingUp className="w-8 h-8 text-green-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Return on Investment</p>
              <p className="text-2xl font-bold text-white">{roi.toFixed(2)}%</p>
              <p className="text-white/40 text-xs">All time</p>
            </div>
            <PieChart className="w-8 h-8 text-purple-400" />
          </div>
        </GlassCard>

        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/60 text-sm">Your Shares</p>
              <p className="text-2xl font-bold text-white">{userShares.toFixed(4)}</p>
              <p className="text-white/40 text-xs">btcVault</p>
            </div>
            <DollarSign className="w-8 h-8 text-yellow-400" />
          </div>
        </GlassCard>
      </div>

      {/* Performance Chart */}
      <GlassCard className="mb-8">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-white">Performance</h3>
          <div className="flex gap-2">
            {(['week', 'month', 'year'] as const).map((period) => (
              <button
                key={period}
                onClick={() => setSelectedPeriod(period)}
                className={cn(
                  'px-3 py-1 rounded-lg text-sm capitalize transition-all duration-300',
                  selectedPeriod === period
                    ? 'bg-white/20 text-white'
                    : 'bg-white/5 text-white/60 hover:bg-white/10'
                )}
              >
                {period}
              </button>
            ))}
          </div>
        </div>
        
        <div className="h-64 flex items-end justify-between gap-3">
          {mockPerformanceData.map((data, index) => (
            <div key={index} className="flex-1 flex flex-col items-center gap-2">
              <div className="relative w-full">
                <div 
                  className="w-full bg-gradient-to-t from-green-500 to-emerald-500 rounded-t-lg hover:opacity-80 transition-opacity"
                  style={{ height: `${(data.value / 110) * 240}px` }}
                />
                <div 
                  className="absolute bottom-0 w-full bg-gradient-to-t from-blue-500/50 to-purple-500/50 rounded-t-lg"
                  style={{ height: `${(100 / 110) * 240}px` }}
                />
              </div>
              <span className="text-xs text-white/40">{data.month}</span>
            </div>
          ))}
        </div>
        
        <div className="mt-4 flex items-center justify-between border-t border-white/10 pt-4">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-gradient-to-r from-green-500 to-emerald-500 rounded-full" />
              <span className="text-xs text-white/60">Portfolio Value</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 bg-gradient-to-r from-blue-500 to-purple-500 rounded-full opacity-50" />
              <span className="text-xs text-white/60">Initial Investment</span>
            </div>
          </div>
          <button
            onClick={exportToCSV}
            className="flex items-center gap-2 px-3 py-1 bg-white/10 hover:bg-white/20 rounded-lg transition-colors"
          >
            <Download className="w-4 h-4 text-white/60" />
            <span className="text-sm text-white/60">Export CSV</span>
          </button>
        </div>
      </GlassCard>

      {/* Transaction History */}
      <GlassCard>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-white">Transaction History</h3>
          <Activity className="w-5 h-5 text-white/40" />
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Type</th>
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Amount</th>
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Shares</th>
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Price</th>
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Date</th>
                <th className="text-left py-3 px-4 text-white/60 text-sm font-medium">Hash</th>
              </tr>
            </thead>
            <tbody>
              {mockTransactionHistory.map((tx) => (
                <tr key={tx.id} className="border-b border-white/5 hover:bg-white/5 transition-colors">
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2">
                      {tx.type === 'deposit' ? (
                        <ArrowDownRight className="w-4 h-4 text-green-400" />
                      ) : (
                        <ArrowUpRight className="w-4 h-4 text-red-400" />
                      )}
                      <span className="text-white capitalize">{tx.type}</span>
                    </div>
                  </td>
                  <td className="py-3 px-4 text-white">{tx.amount} BTC</td>
                  <td className="py-3 px-4 text-white/80">{tx.shares}</td>
                  <td className="py-3 px-4 text-white/80">{tx.price}</td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1 text-white/60">
                      <Clock className="w-3 h-3" />
                      <span className="text-sm">{tx.timestamp.toLocaleDateString()}</span>
                    </div>
                  </td>
                  <td className="py-3 px-4">
                    <span className="text-white/60 text-sm font-mono">
                      {tx.hash.slice(0, 10)}...
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        
        {mockTransactionHistory.length === 0 && (
          <div className="text-center py-8">
            <p className="text-white/40">No transactions yet</p>
          </div>
        )}
      </GlassCard>
    </main>
  );
}