'use client';

import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { BTC_VAULT_STRATEGY_ABI, BTC_VAULT_TOKEN_ABI } from '@/lib/abis';
import { useDeploymentConfig } from './useDeploymentConfig';
import { parseUnits, formatUnits } from 'viem';

export function useVaultContract() {
  const { contracts, isDeployed, collaterals } = useDeploymentConfig();

  // Strategy contract reads
  const { data: totalAssets } = useReadContract(
    isDeployed ? {
      address: contracts?.btcVaultStrategy as `0x${string}`,
      abi: BTC_VAULT_STRATEGY_ABI,
      functionName: 'totalAssets',
    } : undefined
  );

  const { data: availableLiquidity } = useReadContract(
    isDeployed ? {
      address: contracts?.btcVaultStrategy as `0x${string}`,
      abi: BTC_VAULT_STRATEGY_ABI,
      functionName: 'availableLiquidity',
    } : undefined
  );

  // Token contract reads
  const { data: totalSupply } = useReadContract(
    isDeployed ? {
      address: contracts?.btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'totalSupply',
    } : undefined
  );

  const { data: sharePrice } = useReadContract(
    isDeployed ? {
      address: contracts?.btcVaultToken as `0x${string}`,
      abi: BTC_VAULT_TOKEN_ABI,
      functionName: 'convertToAssets',
      args: [parseUnits('1', 8)],
    } : undefined
  );

  // Deposit function
  const depositCollateral = (collateralAddress: string, amount: bigint) => {
    if (!contracts?.btcVaultStrategy) {
      throw new Error('Vault strategy not configured');
    }

    return {
      address: contracts.btcVaultStrategy as `0x${string}`,
      abi: BTC_VAULT_STRATEGY_ABI,
      functionName: 'depositCollateral',
      args: [collateralAddress, amount],
    };
  };

  // Check if collateral is supported
  const isSupportedCollateral = (address: string) => {
    return Object.values(collaterals || {}).some(
      c => c.address.toLowerCase() === address.toLowerCase()
    );
  };

  // Format values for display
  const formatAssets = (value: bigint | undefined) => {
    if (!value) return '0';
    return formatUnits(value, 8); // BTC decimals
  };

  return {
    // Contract addresses
    strategyAddress: contracts?.btcVaultStrategy,
    tokenAddress: contracts?.btcVaultToken,
    
    // Read values
    totalAssets,
    availableLiquidity,
    totalSupply,
    sharePrice,
    
    // Functions
    depositCollateral,
    isSupportedCollateral,
    
    // Helpers
    formatAssets,
    isDeployed,
  };
}