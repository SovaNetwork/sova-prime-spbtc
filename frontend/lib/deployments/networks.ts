import { NetworkConfig } from './registry';

export const NETWORK_TEMPLATES: Record<string, NetworkConfig> = {
  // Mainnets
  ethereum: {
    chainId: 1,
    name: 'Ethereum',
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/',
    blockExplorer: 'https://etherscan.io',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  base: {
    chainId: 8453,
    name: 'Base',
    rpcUrl: 'https://mainnet.base.org',
    blockExplorer: 'https://basescan.org',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  arbitrum: {
    chainId: 42161,
    name: 'Arbitrum One',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    blockExplorer: 'https://arbiscan.io',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  optimism: {
    chainId: 10,
    name: 'Optimism',
    rpcUrl: 'https://mainnet.optimism.io',
    blockExplorer: 'https://optimistic.etherscan.io',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  polygon: {
    chainId: 137,
    name: 'Polygon',
    rpcUrl: 'https://polygon-rpc.com',
    blockExplorer: 'https://polygonscan.com',
    nativeCurrency: {
      name: 'MATIC',
      symbol: 'MATIC',
      decimals: 18,
    },
  },
  avalanche: {
    chainId: 43114,
    name: 'Avalanche',
    rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    blockExplorer: 'https://snowtrace.io',
    nativeCurrency: {
      name: 'AVAX',
      symbol: 'AVAX',
      decimals: 18,
    },
  },
  bsc: {
    chainId: 56,
    name: 'BNB Smart Chain',
    rpcUrl: 'https://bsc-dataseed.binance.org',
    blockExplorer: 'https://bscscan.com',
    nativeCurrency: {
      name: 'BNB',
      symbol: 'BNB',
      decimals: 18,
    },
  },
  
  // Testnets
  sepolia: {
    chainId: 11155111,
    name: 'Sepolia',
    rpcUrl: 'https://sepolia.infura.io/v3/',
    blockExplorer: 'https://sepolia.etherscan.io',
    nativeCurrency: {
      name: 'Sepolia ETH',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  baseSepolia: {
    chainId: 84532,
    name: 'Base Sepolia',
    rpcUrl: 'https://sepolia.base.org',
    blockExplorer: 'https://sepolia.basescan.org',
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  arbitrumSepolia: {
    chainId: 421614,
    name: 'Arbitrum Sepolia',
    rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
    blockExplorer: 'https://sepolia.arbiscan.io',
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  optimismSepolia: {
    chainId: 11155420,
    name: 'Optimism Sepolia',
    rpcUrl: 'https://sepolia.optimism.io',
    blockExplorer: 'https://sepolia-optimism.etherscan.io',
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18,
    },
  },
  polygonAmoy: {
    chainId: 80002,
    name: 'Polygon Amoy',
    rpcUrl: 'https://rpc-amoy.polygon.technology',
    blockExplorer: 'https://amoy.polygonscan.com',
    nativeCurrency: {
      name: 'MATIC',
      symbol: 'MATIC',
      decimals: 18,
    },
  },
  avalancheFuji: {
    chainId: 43113,
    name: 'Avalanche Fuji',
    rpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
    blockExplorer: 'https://testnet.snowtrace.io',
    nativeCurrency: {
      name: 'AVAX',
      symbol: 'AVAX',
      decimals: 18,
    },
  },
};

// Helper to get network by chainId
export function getNetworkTemplate(chainId: number): NetworkConfig | undefined {
  return Object.values(NETWORK_TEMPLATES).find(n => n.chainId === chainId);
}

// Helper to get network name
export function getNetworkName(chainId: number): string {
  const network = getNetworkTemplate(chainId);
  return network?.name || `Chain ${chainId}`;
}

// Helper to check if network is testnet
export function isTestnet(chainId: number): boolean {
  const testnetChainIds = [11155111, 84532, 421614, 11155420, 80002, 43113];
  return testnetChainIds.includes(chainId);
}

// Network categories for UI
export const NETWORK_CATEGORIES = {
  'Layer 1': [1, 137, 56, 43114],
  'Layer 2': [8453, 42161, 10],
  'Testnets': [11155111, 84532, 421614, 11155420, 80002, 43113],
};

// Default RPC endpoints (can be overridden with env vars)
export const DEFAULT_RPC_URLS: Record<number, string> = {
  1: process.env.NEXT_PUBLIC_ETHEREUM_RPC || NETWORK_TEMPLATES.ethereum.rpcUrl,
  8453: process.env.NEXT_PUBLIC_BASE_RPC || NETWORK_TEMPLATES.base.rpcUrl,
  42161: process.env.NEXT_PUBLIC_ARBITRUM_RPC || NETWORK_TEMPLATES.arbitrum.rpcUrl,
  10: process.env.NEXT_PUBLIC_OPTIMISM_RPC || NETWORK_TEMPLATES.optimism.rpcUrl,
  137: process.env.NEXT_PUBLIC_POLYGON_RPC || NETWORK_TEMPLATES.polygon.rpcUrl,
  43114: process.env.NEXT_PUBLIC_AVALANCHE_RPC || NETWORK_TEMPLATES.avalanche.rpcUrl,
  56: process.env.NEXT_PUBLIC_BSC_RPC || NETWORK_TEMPLATES.bsc.rpcUrl,
  11155111: process.env.NEXT_PUBLIC_SEPOLIA_RPC || NETWORK_TEMPLATES.sepolia.rpcUrl,
  84532: process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC || NETWORK_TEMPLATES.baseSepolia.rpcUrl,
};