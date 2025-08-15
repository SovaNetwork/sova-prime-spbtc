import { Address } from 'viem';

export interface NetworkConfig {
  chainId: number;
  rpcUrl: string;
  startBlock: number;
  confirmations: number;
  contracts: {
    vault: Address;
    queue: Address;
    registry: Address;
    strategy: Address;
    priceOracle: Address;
    roleManager: Address;
    wbtc?: Address;
    tbtc?: Address;
    sovaBTC?: Address;
  };
  indexer: {
    maxBlockRange: number;
    pollingInterval: number;
  };
}

export const NETWORK_CONFIGS: Record<string, NetworkConfig> = {
  'base-sepolia': {
    chainId: 84532,
    rpcUrl: process.env.BASE_SEPOLIA_RPC || 'https://base-sepolia.g.alchemy.com/v2/YOUR_KEY',
    startBlock: 12000000, // Update with actual deployment block
    confirmations: 2,
    contracts: {
      vault: '0x73E27097221d4d9D5893a83350dC7A967b46fab7' as Address,
      queue: '0x22BC73098CE1Ba2CaE5431fb32051cB4fc0F9C52' as Address,
      registry: '0x15a9983784617aa8892b2677bbaEc23539482B65' as Address,
      strategy: '0x740907524EbD6A481a81cE76B5115A4cDDb80099' as Address,
      priceOracle: '0xDB4479A2360E118CCbD99B88e82522813BDE48f5' as Address,
      roleManager: '0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72' as Address,
      wbtc: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D' as Address,
      tbtc: '0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802' as Address,
      sovaBTC: '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9' as Address,
    },
    indexer: {
      maxBlockRange: 1000,
      pollingInterval: 12000, // 12 seconds for Base Sepolia
    }
  },
  'base': {
    chainId: 8453,
    rpcUrl: process.env.BASE_MAINNET_RPC || 'https://base-mainnet.g.alchemy.com/v2/YOUR_KEY',
    startBlock: 0, // To be determined after deployment
    confirmations: 12,
    contracts: {
      vault: (process.env.BASE_VAULT_ADDRESS || '') as Address,
      queue: (process.env.BASE_QUEUE_ADDRESS || '') as Address,
      registry: (process.env.BASE_REGISTRY_ADDRESS || '') as Address,
      strategy: (process.env.BASE_STRATEGY_ADDRESS || '') as Address,
      priceOracle: (process.env.BASE_ORACLE_ADDRESS || '') as Address,
      roleManager: (process.env.BASE_ROLE_MANAGER_ADDRESS || '') as Address,
      // Mainnet BTC tokens on Base
      wbtc: '0x1ceA84203673764244E05693e42E6Ace62bE9BA5' as Address, // Placeholder - verify actual address
      tbtc: '' as Address, // To be determined
      sovaBTC: '' as Address, // To be determined
    },
    indexer: {
      maxBlockRange: 500,
      pollingInterval: 2000, // 2 seconds for Base mainnet
    }
  },
  'ethereum': {
    chainId: 1,
    rpcUrl: process.env.ETH_MAINNET_RPC || 'https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY',
    startBlock: 0, // To be determined after deployment
    confirmations: 12,
    contracts: {
      vault: (process.env.ETH_VAULT_ADDRESS || '') as Address,
      queue: (process.env.ETH_QUEUE_ADDRESS || '') as Address,
      registry: (process.env.ETH_REGISTRY_ADDRESS || '') as Address,
      strategy: (process.env.ETH_STRATEGY_ADDRESS || '') as Address,
      priceOracle: (process.env.ETH_ORACLE_ADDRESS || '') as Address,
      roleManager: (process.env.ETH_ROLE_MANAGER_ADDRESS || '') as Address,
      // Mainnet BTC tokens on Ethereum
      wbtc: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address,
      tbtc: '0x18084fbA666a33d37592fA2633fD49a74DD93a88' as Address,
      sovaBTC: '' as Address, // To be determined
    },
    indexer: {
      maxBlockRange: 100,
      pollingInterval: 12000, // 12 seconds for Ethereum
    }
  },
  'arbitrum': {
    chainId: 42161,
    rpcUrl: process.env.ARB_MAINNET_RPC || 'https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY',
    startBlock: 0,
    confirmations: 12,
    contracts: {
      vault: (process.env.ARB_VAULT_ADDRESS || '') as Address,
      queue: (process.env.ARB_QUEUE_ADDRESS || '') as Address,
      registry: (process.env.ARB_REGISTRY_ADDRESS || '') as Address,
      strategy: (process.env.ARB_STRATEGY_ADDRESS || '') as Address,
      priceOracle: (process.env.ARB_ORACLE_ADDRESS || '') as Address,
      roleManager: (process.env.ARB_ROLE_MANAGER_ADDRESS || '') as Address,
      wbtc: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f' as Address, // WBTC on Arbitrum
      tbtc: '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40' as Address, // tBTC on Arbitrum
      sovaBTC: '' as Address,
    },
    indexer: {
      maxBlockRange: 1000,
      pollingInterval: 250, // Fast L2 blocks
    }
  },
  'optimism': {
    chainId: 10,
    rpcUrl: process.env.OP_MAINNET_RPC || 'https://opt-mainnet.g.alchemy.com/v2/YOUR_KEY',
    startBlock: 0,
    confirmations: 12,
    contracts: {
      vault: (process.env.OP_VAULT_ADDRESS || '') as Address,
      queue: (process.env.OP_QUEUE_ADDRESS || '') as Address,
      registry: (process.env.OP_REGISTRY_ADDRESS || '') as Address,
      strategy: (process.env.OP_STRATEGY_ADDRESS || '') as Address,
      priceOracle: (process.env.OP_ORACLE_ADDRESS || '') as Address,
      roleManager: (process.env.OP_ROLE_MANAGER_ADDRESS || '') as Address,
      wbtc: '0x68f180fcCe6836688e9084f035309E29Bf0A2095' as Address, // WBTC on Optimism
      tbtc: '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40' as Address, // tBTC on Optimism
      sovaBTC: '' as Address,
    },
    indexer: {
      maxBlockRange: 1000,
      pollingInterval: 2000,
    }
  }
};

export function getNetworkConfig(): NetworkConfig {
  const network = process.env.NETWORK || 'base-sepolia';
  const config = NETWORK_CONFIGS[network];
  
  if (!config) {
    throw new Error(`Unknown network: ${network}. Available networks: ${Object.keys(NETWORK_CONFIGS).join(', ')}`);
  }
  
  // Allow individual contract overrides from environment variables
  if (process.env.VAULT_ADDRESS) {
    config.contracts.vault = process.env.VAULT_ADDRESS as Address;
  }
  if (process.env.QUEUE_ADDRESS) {
    config.contracts.queue = process.env.QUEUE_ADDRESS as Address;
  }
  if (process.env.REGISTRY_ADDRESS) {
    config.contracts.registry = process.env.REGISTRY_ADDRESS as Address;
  }
  if (process.env.STRATEGY_ADDRESS) {
    config.contracts.strategy = process.env.STRATEGY_ADDRESS as Address;
  }
  if (process.env.PRICE_ORACLE_ADDRESS) {
    config.contracts.priceOracle = process.env.PRICE_ORACLE_ADDRESS as Address;
  }
  if (process.env.ROLE_MANAGER_ADDRESS) {
    config.contracts.roleManager = process.env.ROLE_MANAGER_ADDRESS as Address;
  }
  
  // Override RPC URL if provided
  if (process.env.RPC_URL) {
    config.rpcUrl = process.env.RPC_URL;
  }
  
  // Override start block if provided
  if (process.env.START_BLOCK) {
    config.startBlock = parseInt(process.env.START_BLOCK);
  }
  
  return config;
}

export function validateNetworkConfig(config: NetworkConfig): void {
  const errors: string[] = [];
  
  // Check required addresses
  if (!config.contracts.vault || config.contracts.vault === '0x') {
    errors.push('Vault address is not configured');
  }
  if (!config.contracts.queue || config.contracts.queue === '0x') {
    errors.push('Queue address is not configured');
  }
  if (!config.contracts.registry || config.contracts.registry === '0x') {
    errors.push('Registry address is not configured');
  }
  if (!config.contracts.strategy || config.contracts.strategy === '0x') {
    errors.push('Strategy address is not configured');
  }
  if (!config.contracts.priceOracle || config.contracts.priceOracle === '0x') {
    errors.push('Price Oracle address is not configured');
  }
  
  // Check RPC URL
  if (!config.rpcUrl || config.rpcUrl.includes('YOUR_KEY')) {
    errors.push('RPC URL is not properly configured');
  }
  
  if (errors.length > 0) {
    throw new Error(`Network configuration validation failed:\n${errors.join('\n')}`);
  }
}

export function getNetworkName(chainId: number): string {
  const networkEntry = Object.entries(NETWORK_CONFIGS).find(
    ([_, config]) => config.chainId === chainId
  );
  return networkEntry ? networkEntry[0] : `unknown-${chainId}`;
}

export function isMainnet(network: string): boolean {
  return ['base', 'ethereum', 'arbitrum', 'optimism'].includes(network);
}

export function isTestnet(network: string): boolean {
  return network.includes('sepolia') || network.includes('goerli') || network.includes('testnet');
}