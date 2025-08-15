import { CollateralToken } from './registry';

export const COLLATERAL_TEMPLATES: Record<number, Record<string, CollateralToken>> = {
  // Ethereum Mainnet
  1: {
    WBTC: {
      address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
      oracleId: 'wbtc',
    },
    tBTC: {
      address: '0x18084fbA666a33d37592fA2633fD49a74DD93a88',
      decimals: 18,
      name: 'tBTC v2',
      symbol: 'tBTC',
      oracleId: 'tbtc',
    },
    BTCB: {
      address: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
      decimals: 18,
      name: 'Binance Bitcoin',
      symbol: 'BTCB',
      oracleId: 'btcb',
    },
  },
  
  // Base
  8453: {
    cbBTC: {
      address: '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf',
      decimals: 8,
      name: 'Coinbase Wrapped BTC',
      symbol: 'cbBTC',
      oracleId: 'cbbtc',
    },
    WBTC: {
      address: '0x68f180fcCe6836688e9084f035309E29Bf0A2095',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
      oracleId: 'wbtc',
    },
  },
  
  // Arbitrum One
  42161: {
    WBTC: {
      address: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
      oracleId: 'wbtc',
    },
    tBTC: {
      address: '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40',
      decimals: 18,
      name: 'tBTC v2',
      symbol: 'tBTC',
      oracleId: 'tbtc',
    },
  },
  
  // Optimism
  10: {
    WBTC: {
      address: '0x68f180fcCe6836688e9084f035309E29Bf0A2095',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
      oracleId: 'wbtc',
    },
    tBTC: {
      address: '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40',
      decimals: 18,
      name: 'tBTC v2',
      symbol: 'tBTC',
      oracleId: 'tbtc',
    },
  },
  
  // Polygon
  137: {
    WBTC: {
      address: '0x1bfd67037b42cf73acF2047067bd4F2C47D9BfD6',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
      oracleId: 'wbtc',
    },
  },
  
  // Avalanche
  43114: {
    'WBTC.e': {
      address: '0x50b7545627a5162F82A992c33b87aDc75187B218',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC.e',
      oracleId: 'wbtc',
    },
    BTC: {
      address: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
      decimals: 8,
      name: 'Bitcoin',
      symbol: 'BTC.b',
      oracleId: 'btc',
    },
  },
  
  // Base Sepolia (Testnet)
  84532: {
    WBTC: {
      address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
    },
    sovaBTC: {
      address: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
      decimals: 8,
      name: 'Sova Bitcoin',
      symbol: 'sovaBTC',
    },
  },
  
  // Sepolia (Testnet)
  11155111: {
    WBTC: {
      address: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
      decimals: 8,
      name: 'Wrapped Bitcoin',
      symbol: 'WBTC',
    },
  },
};

// Helper function to get collaterals for a network
export function getNetworkCollaterals(chainId: number): Record<string, CollateralToken> {
  return COLLATERAL_TEMPLATES[chainId] || {};
}

// Helper function to get specific collateral
export function getCollateral(chainId: number, symbol: string): CollateralToken | undefined {
  return COLLATERAL_TEMPLATES[chainId]?.[symbol];
}

// Common collateral symbols across networks
export const COMMON_COLLATERALS = ['WBTC', 'tBTC', 'cbBTC', 'BTCB', 'sovaBTC'];

// Testnet faucet addresses (for testing)
export const TESTNET_FAUCETS: Record<number, string> = {
  11155111: 'https://sepoliafaucet.com',
  84532: 'https://faucet.quicknode.com/base/sepolia',
  421614: 'https://faucet.quicknode.com/arbitrum/sepolia',
  11155420: 'https://faucet.quicknode.com/optimism/sepolia',
  80002: 'https://faucet.polygon.technology',
  43113: 'https://faucet.avax.network',
};