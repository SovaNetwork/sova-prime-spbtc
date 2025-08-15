// Network configuration for multi-chain support
export interface NetworkConfig {
  id: number;
  name: string;
  displayName: string;
  color: string;
  rpcUrl: string;
  explorerUrl: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  contracts: {
    btcVaultStrategy: string;
    btcVaultToken: string;
    priceOracle: string;
  };
  collateralTokens: {
    address: string;
    symbol: string;
    name: string;
    decimals: number;
  }[];
}

export const NETWORKS: NetworkConfig[] = [
  {
    id: 84532,
    name: 'base-sepolia',
    displayName: 'Base Sepolia',
    color: 'bg-blue-500',
    rpcUrl: 'https://sepolia.base.org',
    explorerUrl: 'https://sepolia.basescan.org',
    nativeCurrency: {
      name: 'Ethereum',
      symbol: 'ETH',
      decimals: 18,
    },
    contracts: {
      btcVaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
      btcVaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
      priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
    },
    collateralTokens: [
      {
        address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
        symbol: 'sovaBTC',
        name: 'Sova Bitcoin',
        decimals: 8,
      },
      {
        address: '0x1234567890123456789012345678901234567890',
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin',
        decimals: 8,
      },
      {
        address: '0x2345678901234567890123456789012345678901',
        symbol: 'tBTC',
        name: 'tBTC v2',
        decimals: 18,
      },
    ],
  },
  {
    id: 8453,
    name: 'base',
    displayName: 'Base',
    color: 'bg-blue-600',
    rpcUrl: 'https://mainnet.base.org',
    explorerUrl: 'https://basescan.org',
    nativeCurrency: {
      name: 'Ethereum',
      symbol: 'ETH',
      decimals: 18,
    },
    contracts: {
      btcVaultStrategy: '0x0000000000000000000000000000000000000000', // To be deployed
      btcVaultToken: '0x0000000000000000000000000000000000000000', // To be deployed
      priceOracle: '0x0000000000000000000000000000000000000000', // To be deployed
    },
    collateralTokens: [
      {
        address: '0x0000000000000000000000000000000000000000',
        symbol: 'sovaBTC',
        name: 'Sova Bitcoin',
        decimals: 8,
      },
    ],
  },
  {
    id: 1,
    name: 'ethereum',
    displayName: 'Ethereum',
    color: 'bg-gray-500',
    rpcUrl: 'https://ethereum.publicnode.com',
    explorerUrl: 'https://etherscan.io',
    nativeCurrency: {
      name: 'Ethereum',
      symbol: 'ETH',
      decimals: 18,
    },
    contracts: {
      btcVaultStrategy: '0x0000000000000000000000000000000000000000', // To be deployed
      btcVaultToken: '0x0000000000000000000000000000000000000000', // To be deployed
      priceOracle: '0x0000000000000000000000000000000000000000', // To be deployed
    },
    collateralTokens: [
      {
        address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin',
        decimals: 8,
      },
      {
        address: '0x18084fbA666a33d37592fA2633fD49a74DD93a88',
        symbol: 'tBTC',
        name: 'tBTC v2',
        decimals: 18,
      },
    ],
  },
  {
    id: 42161,
    name: 'arbitrum',
    displayName: 'Arbitrum',
    color: 'bg-orange-500',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    explorerUrl: 'https://arbiscan.io',
    nativeCurrency: {
      name: 'Ethereum',
      symbol: 'ETH',
      decimals: 18,
    },
    contracts: {
      btcVaultStrategy: '0x0000000000000000000000000000000000000000', // To be deployed
      btcVaultToken: '0x0000000000000000000000000000000000000000', // To be deployed
      priceOracle: '0x0000000000000000000000000000000000000000', // To be deployed
    },
    collateralTokens: [
      {
        address: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin',
        decimals: 8,
      },
    ],
  },
  {
    id: 10,
    name: 'optimism',
    displayName: 'Optimism',
    color: 'bg-red-500',
    rpcUrl: 'https://mainnet.optimism.io',
    explorerUrl: 'https://optimistic.etherscan.io',
    nativeCurrency: {
      name: 'Ethereum',
      symbol: 'ETH',
      decimals: 18,
    },
    contracts: {
      btcVaultStrategy: '0x0000000000000000000000000000000000000000', // To be deployed
      btcVaultToken: '0x0000000000000000000000000000000000000000', // To be deployed
      priceOracle: '0x0000000000000000000000000000000000000000', // To be deployed
    },
    collateralTokens: [
      {
        address: '0x68f180fcCe6836688e9084f035309E29Bf0A2095',
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin',
        decimals: 8,
      },
    ],
  },
];

export function getNetworkById(chainId: number): NetworkConfig | undefined {
  return NETWORKS.find((network) => network.id === chainId);
}

export function getNetworkByName(name: string): NetworkConfig | undefined {
  return NETWORKS.find((network) => network.name === name);
}

export function getSupportedChainIds(): number[] {
  return NETWORKS.map((network) => network.id);
}

export function isNetworkSupported(chainId: number): boolean {
  return NETWORKS.some((network) => network.id === chainId);
}

// Helper to switch network using wallet
export async function switchNetwork(chainId: number): Promise<void> {
  const network = getNetworkById(chainId);
  if (!network) {
    throw new Error(`Network ${chainId} not supported`);
  }

  try {
    await window.ethereum?.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: `0x${chainId.toString(16)}` }],
    });
  } catch (error: any) {
    // This error code indicates that the chain has not been added to MetaMask
    if (error.code === 4902) {
      await window.ethereum?.request({
        method: 'wallet_addEthereumChain',
        params: [
          {
            chainId: `0x${chainId.toString(16)}`,
            chainName: network.displayName,
            nativeCurrency: network.nativeCurrency,
            rpcUrls: [network.rpcUrl],
            blockExplorerUrls: [network.explorerUrl],
          },
        ],
      });
    } else {
      throw error;
    }
  }
}