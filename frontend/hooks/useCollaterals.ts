import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAccount } from 'wagmi';

export interface Collateral {
  id: string;
  deploymentId: string;
  symbol: string;
  name: string;
  address: string;
  chainId: number;
  decimals: number;
  oracleId?: string | null;
  logoUri?: string | null;
  coingeckoId?: string | null;
  isActive: boolean;
  isVerified: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface TokenRegistryEntry {
  id: string;
  symbol: string;
  name: string;
  addresses: Record<string, string>;
  decimals: number;
  logoUri?: string | null;
  coingeckoId?: string | null;
  category?: string | null;
}

/**
 * Hook to fetch collaterals for a specific network/deployment
 */
export function useCollaterals(chainId?: number, deploymentId?: string) {
  return useQuery<Collateral[]>({
    queryKey: ['collaterals', chainId, deploymentId],
    queryFn: async () => {
      const params = new URLSearchParams();
      if (chainId) params.append('chainId', chainId.toString());
      if (deploymentId) params.append('deploymentId', deploymentId);

      const response = await fetch(`/api/collaterals?${params}`);
      if (!response.ok) {
        throw new Error('Failed to fetch collaterals');
      }
      return response.json();
    },
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to fetch active collaterals for current network
 */
export function useActiveCollaterals() {
  const { chain } = useAccount();
  const chainId = chain?.id;

  return useQuery<Collateral[]>({
    queryKey: ['collaterals', 'active', chainId],
    queryFn: async () => {
      if (!chainId) return [];

      const params = new URLSearchParams();
      params.append('chainId', chainId.toString());

      const response = await fetch(`/api/collaterals?${params}`);
      if (!response.ok) {
        throw new Error('Failed to fetch collaterals');
      }
      
      const collaterals: Collateral[] = await response.json();
      // Filter only active collaterals
      return collaterals.filter(c => c.isActive);
    },
    enabled: !!chainId,
    staleTime: 30 * 1000,
  });
}

/**
 * Hook to sync collaterals from blockchain
 */
export function useSyncCollaterals() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ deploymentId, chainId }: { deploymentId: string; chainId: number }) => {
      const response = await fetch('/api/collaterals/sync', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ deploymentId, chainId }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to sync collaterals');
      }

      return response.json();
    },
    onSuccess: (data, variables) => {
      // Invalidate collaterals cache
      queryClient.invalidateQueries({ 
        queryKey: ['collaterals', variables.chainId] 
      });
      queryClient.invalidateQueries({ 
        queryKey: ['collaterals', undefined, variables.deploymentId] 
      });
    },
  });
}

/**
 * Hook to add a new collateral
 */
export function useAddCollateral() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (collateral: Omit<Collateral, 'id' | 'createdAt' | 'updatedAt' | 'isActive' | 'isVerified'>) => {
      const response = await fetch('/api/collaterals', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(collateral),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to add collateral');
      }

      return response.json();
    },
    onSuccess: (data, variables) => {
      // Invalidate collaterals cache
      queryClient.invalidateQueries({ 
        queryKey: ['collaterals', variables.chainId] 
      });
      queryClient.invalidateQueries({ 
        queryKey: ['collaterals', undefined, variables.deploymentId] 
      });
    },
  });
}

/**
 * Hook to update collateral metadata
 */
export function useUpdateCollateral() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ 
      id, 
      ...updates 
    }: { 
      id: string; 
      isActive?: boolean;
      isVerified?: boolean;
      logoUri?: string;
      coingeckoId?: string;
      oracleId?: string;
    }) => {
      const response = await fetch(`/api/collaterals/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to update collateral');
      }

      return response.json();
    },
    onSuccess: () => {
      // Invalidate all collaterals cache
      queryClient.invalidateQueries({ queryKey: ['collaterals'] });
    },
  });
}

/**
 * Hook to fetch token registry
 */
export function useTokenRegistry(category?: string) {
  return useQuery<TokenRegistryEntry[]>({
    queryKey: ['token-registry', category],
    queryFn: async () => {
      const params = new URLSearchParams();
      if (category) params.append('category', category);

      const response = await fetch(`/api/token-registry?${params}`);
      if (!response.ok) {
        throw new Error('Failed to fetch token registry');
      }
      return response.json();
    },
    staleTime: 60 * 1000, // 1 minute
  });
}

/**
 * Hook to get token addresses across all networks
 */
export function useTokenAddresses(symbol: string) {
  const { data: registry } = useTokenRegistry();

  const token = registry?.find(t => t.symbol === symbol);
  return token?.addresses || {};
}