'use client';

import { useEffect, useState } from 'react';
import { formatUnits } from 'viem';
import { GlassCard } from '@/components/GlassCard';
import { TrendingUp, Globe, Layers, Activity, RefreshCw } from 'lucide-react';
import { cn } from '@/lib/utils';

interface ChainMetrics {
  chainId: number;
  chainName: string;
  tvl: string;
  totalDeposits: string;
  totalWithdrawals: string;
  sharePrice: string;
  totalUsers: number;
  lastUpdated: string;
}

interface AggregateMetrics {
  totalTvl: number;
  totalDeposits: number;
  totalWithdrawals: number;
  totalUsers: number;
  chains: ChainMetrics[];
}

export function CrossChainMetrics() {
  const [metrics, setMetrics] = useState<AggregateMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMetrics = async () => {
    try {
      setLoading(true);
      const response = await fetch('/api/metrics/aggregate');
      if (!response.ok) throw new Error('Failed to fetch metrics');
      const data = await response.json();
      setMetrics(data);
      setError(null);
    } catch (err) {
      console.error('Error fetching cross-chain metrics:', err);
      setError('Failed to load cross-chain metrics');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMetrics();
    // Refresh every minute
    const interval = setInterval(fetchMetrics, 60000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <GlassCard className="p-6">
        <div className="flex items-center justify-center">
          <RefreshCw className="w-6 h-6 text-white/40 animate-spin" />
          <span className="ml-2 text-white/60">Loading cross-chain metrics...</span>
        </div>
      </GlassCard>
    );
  }

  if (error || !metrics) {
    return (
      <GlassCard className="p-6">
        <div className="text-center text-red-400">
          {error || 'No metrics available'}
        </div>
      </GlassCard>
    );
  }

  const netFlow = metrics.totalDeposits - metrics.totalWithdrawals;

  return (
    <div className="space-y-6">
      {/* Aggregate Metrics Header */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <GlassCard className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-white/60 uppercase tracking-wider">Total TVL</p>
              <p className="text-2xl font-bold text-white">
                {metrics.totalTvl.toFixed(4)} BTC
              </p>
              <p className="text-xs text-white/40 mt-1">
                Across {metrics.chains.length} networks
              </p>
            </div>
            <Globe className="w-8 h-8 text-mint-400" />
          </div>
        </GlassCard>

        <GlassCard className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-white/60 uppercase tracking-wider">Net Flow</p>
              <p className={cn(
                "text-2xl font-bold",
                netFlow >= 0 ? "text-green-400" : "text-red-400"
              )}>
                {netFlow >= 0 ? '+' : ''}{netFlow.toFixed(4)} BTC
              </p>
              <p className="text-xs text-white/40 mt-1">
                All-time net deposits
              </p>
            </div>
            <TrendingUp className="w-8 h-8 text-green-400" />
          </div>
        </GlassCard>

        <GlassCard className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-white/60 uppercase tracking-wider">Active Networks</p>
              <p className="text-2xl font-bold text-white">
                {metrics.chains.length}
              </p>
              <p className="text-xs text-white/40 mt-1">
                Deployed contracts
              </p>
            </div>
            <Layers className="w-8 h-8 text-blue-400" />
          </div>
        </GlassCard>

        <GlassCard className="p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-white/60 uppercase tracking-wider">Total Users</p>
              <p className="text-2xl font-bold text-white">
                {metrics.totalUsers.toLocaleString()}
              </p>
              <p className="text-xs text-white/40 mt-1">
                Unique depositors
              </p>
            </div>
            <Activity className="w-8 h-8 text-orange-400" />
          </div>
        </GlassCard>
      </div>

      {/* Per-Chain Breakdown */}
      <GlassCard className="p-6">
        <h3 className="text-lg font-semibold text-white mb-4">Network Breakdown</h3>
        <div className="space-y-3">
          {metrics.chains.map((chain) => {
            const tvl = parseFloat(formatUnits(BigInt(chain.tvl), 8));
            const deposits = parseFloat(formatUnits(BigInt(chain.totalDeposits), 8));
            const withdrawals = parseFloat(formatUnits(BigInt(chain.totalWithdrawals), 8));
            const sharePrice = parseFloat(formatUnits(BigInt(chain.sharePrice), 18));
            const tvlPercentage = metrics.totalTvl > 0 ? (tvl / metrics.totalTvl) * 100 : 0;

            return (
              <div 
                key={chain.chainId}
                className="flex items-center justify-between p-3 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div>
                    <p className="font-medium text-white">{chain.chainName}</p>
                    <p className="text-xs text-white/60">Chain ID: {chain.chainId}</p>
                  </div>
                </div>

                <div className="flex items-center gap-6">
                  <div className="text-right">
                    <p className="text-sm font-medium text-white">{tvl.toFixed(4)} BTC</p>
                    <p className="text-xs text-white/40">{tvlPercentage.toFixed(1)}% of total</p>
                  </div>

                  <div className="text-right">
                    <p className="text-xs text-green-400">+{deposits.toFixed(4)}</p>
                    <p className="text-xs text-red-400">-{withdrawals.toFixed(4)}</p>
                  </div>

                  <div className="text-right">
                    <p className="text-xs text-white/60">Share Price</p>
                    <p className="text-sm font-medium text-white">{sharePrice.toFixed(6)}</p>
                  </div>

                  <div className="text-right">
                    <p className="text-xs text-white/60">Users</p>
                    <p className="text-sm font-medium text-white">{chain.totalUsers}</p>
                  </div>
                </div>

                {/* TVL Progress Bar */}
                <div className="w-32">
                  <div className="h-2 bg-white/10 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gradient-to-r from-mint-500 to-mint-500 rounded-full transition-all"
                      style={{ width: `${Math.min(tvlPercentage, 100)}%` }}
                    />
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {metrics.chains.length === 0 && (
          <div className="text-center py-8 text-white/40">
            No deployed networks found. Deploy contracts to see metrics.
          </div>
        )}
      </GlassCard>
    </div>
  );
}