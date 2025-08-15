// Legacy contract configuration - use useNetworkContracts hook instead
export const CONTRACTS = {
  // New BTC Vault Contracts (deployed on Base Sepolia)
  btcVaultToken: "0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a", // BtcVaultToken - deployed
  btcVaultStrategy: "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8", // BtcVaultStrategy - deployed
  
  // Supporting contracts (existing)
  roleManager: "0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72",
  
  // Token addresses (Base Sepolia test tokens)
  wbtc: "0xe44b2870eFcd6Bb3C9305808012621f438e9636D", // Test BTC token 1
  tbtc: "0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802", // Test BTC token 2  
  sovaBTC: "0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9", // Main sovaBTC token (asset)
  
  // Old contracts (deprecated - remove after migration)
  vault: "0x73E27097221d4d9D5893a83350dC7A967b46fab7",
  queue: "0x22BC73098CE1BA2CaE5431fb32051cB4fc0F9C52",
  registry: "0x15a9983784617aa8892b2677bbaEc23539482B65",
  strategy: "0x740907524EbD6A481a81cE76B5115A4cDDb80099",
  priceOracle: "0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF", // Updated to new oracle
} as const;

export const CHAIN_CONFIG = {
  id: 84532,
  name: "Base Sepolia",
  network: "base-sepolia",
  nativeCurrency: {
    decimals: 18,
    name: "Ethereum",
    symbol: "ETH",
  },
  rpcUrls: {
    default: {
      http: ["https://base-sepolia.g.alchemy.com/v2/e7qIcHOK60Sc4-hvyWA68"],
    },
    public: {
      http: ["https://sepolia.base.org"],
    },
  },
  blockExplorers: {
    default: { name: "BaseScan", url: "https://sepolia.basescan.org" },
  },
  testnet: true,
};