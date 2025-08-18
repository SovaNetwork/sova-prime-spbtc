'use client';

import { useReadContract, useAccount, useChainId } from 'wagmi';
import { formatUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '@/lib/abis';
import { useVaultMetrics } from '@/hooks/useVaultMetrics';
import { TrendingUpIcon, TrendingDownIcon, ActivityIcon, Globe } from 'lucide-react';
import { useState, useEffect } from 'react';

interface ChainMetrics {
  chainId: number;
  tvl: number;
  shares: number;
  sharePrice: number;
}

export function VaultStats() {
  const { address } = useAccount();
  const chainId = useChainId();
  const [showAggregate, setShowAggregate] = useState(false);
  const [aggregateMetrics, setAggregateMetrics] = useState<ChainMetrics[]>([]);

  // Get data from GraphQL (indexed blockchain data)
  const { metrics: indexedMetrics, loading: metricsLoading } = useVaultMetrics();

  // Get real-time data from contracts
  const { data: totalAssets } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalAssets',
  });

  const { data: totalSupply } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalSupply',
  });

  const { data: userBalance } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: availableLiquidity } = useReadContract({
    address: CONTRACTS.btcVaultStrategy as `0x${string}`,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'availableLiquidity',
  });

  // Use indexed data if available, fallback to contract data
  const tvl = indexedMetrics?.totalAssets 
    ? Number(formatUnits(BigInt(indexedMetrics.totalAssets), 8))
    : totalAssets 
    ? Number(formatUnits(totalAssets, 8)) 
    : 0;

  const shares = indexedMetrics?.totalSupply
    ? Number(formatUnits(BigInt(indexedMetrics.totalSupply), 18))
    : totalSupply 
    ? Number(formatUnits(totalSupply, 18)) 
    : 0;

  const userShares = userBalance ? Number(formatUnits(userBalance, 18)) : 0;
  const liquidity = availableLiquidity ? Number(formatUnits(availableLiquidity, 8)) : 0;
  
  // Calculate share price from indexed data or contract data
  const price = indexedMetrics?.sharePrice
    ? Number(formatUnits(BigInt(indexedMetrics.sharePrice), 18))
    : shares > 0 && totalAssets 
    ? (tvl / shares) 
    : 1;

  // Calculate utilization rate
  const utilizationRate = tvl > 0 ? ((tvl - liquidity) / tvl) * 100 : 0;

  // Fetch aggregate metrics if enabled
  useEffect(() => {
    if (showAggregate) {
      fetch('/api/metrics/aggregate')
        .then(res => res.json())
        .then(data => {
          if (data.chains) {
            setAggregateMetrics(data.chains.map((c: any) => ({
              chainId: c.chainId,
              tvl: parseFloat(formatUnits(BigInt(c.tvl), 8)),
              shares: parseFloat(formatUnits(BigInt(c.totalSupply || '0'), 18)),
              sharePrice: parseFloat(formatUnits(BigInt(c.sharePrice || '1000000000000000000'), 18))
            })));
          }
        })
        .catch(console.error);
    }
  }, [showAggregate]);

  // Calculate total TVL across all chains
  const totalTvl = showAggregate 
    ? aggregateMetrics.reduce((sum, m) => sum + m.tvl, 0)
    : tvl;

  return (
    <div>
      {/* Toggle for aggregate view */}
      <div className="flex justify-end mb-4">
        <button
          onClick={() => setShowAggregate(!showAggregate)}
          className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 transition-colors"
        >
          <Globe className="w-4 h-4" />
          <span className="text-sm">
            {showAggregate ? 'Current Chain' : 'All Chains'}
          </span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-sm text-gray-400">
            {showAggregate ? 'Total TVL (All Chains)' : 'Total Value Locked'}
          </h3>
          {(indexedMetrics || showAggregate) && (
            <ActivityIcon className="w-4 h-4 text-mint-400 animate-pulse" />
          )}
        </div>
        <p className="text-2xl font-bold text-white">{totalTvl.toFixed(4)} BTC</p>
        {showAggregate ? (
          <p className="text-xs text-gray-500 mt-1">{aggregateMetrics.length} networks</p>
        ) : metricsLoading ? (
          <p className="text-xs text-gray-500 mt-1">Loading live data...</p>
        ) : null}
      </div>
      
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <h3 className="text-sm text-gray-400 mb-2">Total Shares</h3>
        <p className="text-2xl font-bold text-white">{shares.toFixed(2)} btcVault</p>
        <p className="text-xs text-gray-500 mt-1">
          {utilizationRate.toFixed(1)}% utilized
        </p>
      </div>
      
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <h3 className="text-sm text-gray-400 mb-2">Share Price</h3>
        <p className="text-2xl font-bold text-white">{price.toFixed(6)} BTC</p>
        <div className="flex items-center gap-1 mt-1">
          {price > 1 ? (
            <>
              <TrendingUpIcon className="w-3 h-3 text-green-400" />
              <span className="text-xs text-green-400">+{((price - 1) * 100).toFixed(2)}%</span>
            </>
          ) : price < 1 ? (
            <>
              <TrendingDownIcon className="w-3 h-3 text-red-400" />
              <span className="text-xs text-red-400">{((price - 1) * 100).toFixed(2)}%</span>
            </>
          ) : (
            <span className="text-xs text-gray-500">1:1 ratio</span>
          )}
        </div>
      </div>
      
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <h3 className="text-sm text-gray-400 mb-2">Available Liquidity</h3>
        <p className="text-2xl font-bold text-white">{liquidity.toFixed(4)} sovaBTC</p>
        <p className="text-xs text-gray-500 mt-1">
          Ready for withdrawals
        </p>
      </div>
      
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <h3 className="text-sm text-gray-400 mb-2">Your Balance</h3>
        <p className="text-2xl font-bold text-white">{userShares.toFixed(4)} btcVault</p>
        <p className="text-sm text-gray-400 mt-1">≈ {(userShares * price).toFixed(6)} BTC</p>
      </div>

      {/* Last Updated Indicator */}
      {indexedMetrics?.timestamp && (
        <div className="col-span-full text-center text-xs text-gray-500">
          Last indexed: {new Date(indexedMetrics.timestamp * 1000).toLocaleString()}
          {showAggregate && ` • Chain ${chainId}`}
        </div>
      )}
    </div>
    </div>
  );
}