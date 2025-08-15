import { useQuery } from '@apollo/client';
import { GET_VAULT_METRICS, GET_VAULT_STATS } from '@/lib/queries';
import { useMemo } from 'react';

interface VaultMetrics {
  totalAssets: string;
  totalSupply: string;
  sharePrice: string;
  timestamp: number;
}

export function useVaultMetrics() {
  const { data, loading, error, refetch } = useQuery(GET_VAULT_METRICS, {
    pollInterval: 30000, // Refresh every 30 seconds
    notifyOnNetworkStatusChange: true,
  });

  const metrics = useMemo(() => {
    if (!data?.vaultMetricss?.items?.[0]) return null;
    
    const raw = data.vaultMetricss.items[0];
    return {
      totalAssets: raw.totalAssets,
      totalSupply: raw.totalShares, // Changed from totalSupply to totalShares
      sharePrice: raw.sharePrice,
      timestamp: raw.timestamp,
      tvl: raw.totalAssets, // TVL is total assets
    };
  }, [data]);

  return {
    metrics,
    loading,
    error,
    refetch,
  };
}

export function useVaultStats() {
  const { data, loading, error } = useQuery(GET_VAULT_STATS, {
    pollInterval: 60000, // Refresh every minute
  });

  const stats = useMemo(() => {
    if (!data) return null;

    const metrics = data.vaultMetricss?.items?.[0];
    
    return {
      totalAssets: metrics?.totalAssets || '0',
      totalSupply: metrics?.totalShares || '0', // Changed to totalShares
      sharePrice: metrics?.sharePrice || '0',
      totalDeposits: metrics?.totalDeposits || '0', // Now coming directly from metrics
      totalWithdrawals: metrics?.totalWithdrawals || '0', // Now coming directly from metrics
      netFlow: ((BigInt(metrics?.totalDeposits || 0) - BigInt(metrics?.totalWithdrawals || 0)).toString()),
      totalUsers: metrics?.totalUsers || 0,
      activeUsers: metrics?.activeUsers || 0,
    };
  }, [data]);

  return {
    stats,
    loading,
    error,
  };
}