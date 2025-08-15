'use client';

import { useState, useEffect, useCallback } from 'react';
import { DeploymentRegistry } from '@/lib/deployments/registry';

let globalRegistry: DeploymentRegistry | null = null;

export function useDeploymentRegistry() {
  const [registry, setRegistry] = useState<DeploymentRegistry | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try {
      // Use singleton pattern for registry
      if (!globalRegistry) {
        globalRegistry = new DeploymentRegistry();
      }
      setRegistry(globalRegistry);
      setIsLoading(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to initialize registry');
      setIsLoading(false);
    }
  }, []);

  const refresh = useCallback(() => {
    if (registry) {
      // Force reload from storage
      globalRegistry = new DeploymentRegistry();
      setRegistry(globalRegistry);
    }
  }, [registry]);

  const addDeployment = useCallback((chainId: number, deployment: any) => {
    if (registry) {
      registry.addDeployment(chainId, deployment);
      refresh();
    }
  }, [registry, refresh]);

  const updateDeployment = useCallback((chainId: number, updates: any) => {
    if (registry) {
      registry.updateDeployment(chainId, updates);
      refresh();
    }
  }, [registry, refresh]);

  const removeDeployment = useCallback((chainId: number) => {
    if (registry) {
      registry.removeDeployment(chainId);
      refresh();
    }
  }, [registry, refresh]);

  const exportConfig = useCallback(() => {
    if (registry) {
      return registry.exportConfig();
    }
    return null;
  }, [registry]);

  const importConfig = useCallback((json: string) => {
    if (registry) {
      registry.importConfig(json);
      refresh();
    }
  }, [registry, refresh]);

  return {
    registry,
    isLoading,
    error,
    refresh,
    addDeployment,
    updateDeployment,
    removeDeployment,
    exportConfig,
    importConfig,
  };
}