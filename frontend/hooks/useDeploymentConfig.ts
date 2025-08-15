'use client';

import { useMemo } from 'react';
import { useChainId, useSwitchChain } from 'wagmi';
import { DeploymentRegistry, DeploymentInfo } from '@/lib/deployments/registry';
import { useDeploymentRegistry } from './useDeploymentRegistry';

export function useDeploymentConfig() {
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { registry, isLoading, refresh } = useDeploymentRegistry();

  const deployment = useMemo(() => {
    if (!registry || isLoading) return null;
    return registry.getDeployment(chainId);
  }, [chainId, registry, isLoading]);

  const isDeployed = useMemo(() => {
    return deployment?.status === 'active';
  }, [deployment]);

  const switchToNetwork = async (targetChainId: number) => {
    if (switchChain) {
      await switchChain({ chainId: targetChainId });
    }
  };

  const availableNetworks = useMemo(() => {
    if (!registry) return [];
    return registry.getActiveDeployments().map(d => ({
      chainId: d.network.chainId,
      name: d.network.name,
    }));
  }, [registry]);

  return {
    deployment,
    contracts: deployment?.contracts,
    collaterals: deployment?.collaterals,
    network: deployment?.network,
    isDeployed,
    isLoading,
    chainId,
    switchToNetwork,
    availableNetworks,
    refresh,
  };
}