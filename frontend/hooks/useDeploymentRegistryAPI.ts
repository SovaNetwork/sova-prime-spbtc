'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { deploymentRegistry, DeploymentInfo } from '@/lib/deployments/registry-api';
import { useCallback } from 'react';
import toast from 'react-hot-toast';

export function useDeploymentRegistryAPI() {
  const queryClient = useQueryClient();

  // Fetch all deployments
  const { data: deployments = [], isLoading, error } = useQuery({
    queryKey: ['deployments'],
    queryFn: async () => {
      await deploymentRegistry.loadDeployments();
      return deploymentRegistry.getAllDeployments();
    },
    refetchInterval: 60000, // Refetch every minute
    staleTime: 30000, // Consider data stale after 30 seconds
  });

  // Get active deployments
  const activeDeployments = deployments.filter(d => d.status === 'active');

  // Add deployment mutation
  const addDeploymentMutation = useMutation({
    mutationFn: async ({ chainId, deployment }: { chainId: number; deployment: DeploymentInfo }) => {
      await deploymentRegistry.addDeployment(chainId, deployment);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('Deployment added successfully');
    },
    onError: (error) => {
      toast.error(`Failed to add deployment: ${error}`);
    },
  });

  // Update deployment mutation
  const updateDeploymentMutation = useMutation({
    mutationFn: async ({ chainId, updates }: { chainId: number; updates: Partial<DeploymentInfo> }) => {
      await deploymentRegistry.updateDeployment(chainId, updates);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('Deployment updated successfully');
    },
    onError: (error) => {
      toast.error(`Failed to update deployment: ${error}`);
    },
  });

  // Remove deployment mutation
  const removeDeploymentMutation = useMutation({
    mutationFn: async (chainId: number) => {
      await deploymentRegistry.removeDeployment(chainId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('Deployment removed successfully');
    },
    onError: (error) => {
      toast.error(`Failed to remove deployment: ${error}`);
    },
  });

  // Collect metrics mutation
  const collectMetricsMutation = useMutation({
    mutationFn: async (chainId: number) => {
      await deploymentRegistry.collectMetrics(chainId);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('Metrics collected successfully');
    },
    onError: (error) => {
      toast.error(`Failed to collect metrics: ${error}`);
    },
  });

  // Helper functions
  const getDeployment = useCallback((chainId: number) => {
    return deployments.find(d => d.network.chainId === chainId) || null;
  }, [deployments]);

  const hasDeployment = useCallback((chainId: number) => {
    return deployments.some(d => d.network.chainId === chainId);
  }, [deployments]);

  const exportConfig = useCallback(() => {
    return deploymentRegistry.exportConfig();
  }, []);

  const importConfig = useCallback(async (json: string) => {
    try {
      await deploymentRegistry.importConfig(json);
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('Configuration imported successfully');
    } catch (error) {
      toast.error(`Failed to import configuration: ${error}`);
    }
  }, [queryClient]);

  const clearAll = useCallback(async () => {
    try {
      await deploymentRegistry.clearAll();
      queryClient.invalidateQueries({ queryKey: ['deployments'] });
      toast.success('All deployments cleared');
    } catch (error) {
      toast.error(`Failed to clear deployments: ${error}`);
    }
  }, [queryClient]);

  return {
    // Data
    deployments,
    activeDeployments,
    isLoading,
    error: error as Error | null,
    
    // Queries
    getDeployment,
    hasDeployment,
    
    // Mutations
    addDeployment: addDeploymentMutation.mutate,
    updateDeployment: updateDeploymentMutation.mutate,
    removeDeployment: removeDeploymentMutation.mutate,
    collectMetrics: collectMetricsMutation.mutate,
    
    // Utilities
    exportConfig,
    importConfig,
    clearAll,
    
    // Loading states
    isAddingDeployment: addDeploymentMutation.isPending,
    isUpdatingDeployment: updateDeploymentMutation.isPending,
    isRemovingDeployment: removeDeploymentMutation.isPending,
    isCollectingMetrics: collectMetricsMutation.isPending,
  };
}