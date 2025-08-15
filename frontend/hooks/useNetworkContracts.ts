'use client';

import { useChainId } from 'wagmi';
import { getNetworkById } from '@/lib/networks';
import { CONTRACTS } from '@/lib/contracts';

export function useNetworkContracts() {
  const chainId = useChainId();
  const network = getNetworkById(chainId);

  // If network is not configured, fall back to Base Sepolia contracts
  if (!network) {
    return {
      btcVaultStrategy: CONTRACTS.btcVaultStrategy,
      btcVaultToken: CONTRACTS.btcVaultToken,
      priceOracle: CONTRACTS.priceOracle,
      collateralTokens: [
        {
          address: CONTRACTS.sovaBTC,
          symbol: 'sovaBTC',
          name: 'Sova Bitcoin',
          decimals: 8,
        },
      ],
      explorerUrl: 'https://sepolia.basescan.org',
      isSupported: false,
    };
  }

  return {
    btcVaultStrategy: network.contracts.btcVaultStrategy,
    btcVaultToken: network.contracts.btcVaultToken,
    priceOracle: network.contracts.priceOracle,
    collateralTokens: network.collateralTokens,
    explorerUrl: network.explorerUrl,
    isSupported: true,
    networkName: network.displayName,
    chainId: network.id,
  };
}

export function useExplorerUrl() {
  const { explorerUrl } = useNetworkContracts();
  
  return {
    tx: (hash: string) => `${explorerUrl}/tx/${hash}`,
    address: (address: string) => `${explorerUrl}/address/${address}`,
    block: (block: number | string) => `${explorerUrl}/block/${block}`,
  };
}