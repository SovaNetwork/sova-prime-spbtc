import { createConfig } from "@ponder/core";
import { http } from "viem";
import BtcVaultTokenAbi from "./abis/BtcVaultToken.json";
import BtcVaultStrategyAbi from "./abis/BtcVaultStrategy.json";

// Multi-chain network configuration
const networks = {
  ethereum: {
    chainId: 1,
    transport: http(process.env.ETHEREUM_RPC_URL || "https://eth-mainnet.g.alchemy.com/v2/demo"),
  },
  base: {
    chainId: 8453,
    transport: http(process.env.BASE_RPC_URL || "https://mainnet.base.org"),
  },
  arbitrum: {
    chainId: 42161,
    transport: http(process.env.ARBITRUM_RPC_URL || "https://arb1.arbitrum.io/rpc"),
  },
  optimism: {
    chainId: 10,
    transport: http(process.env.OPTIMISM_RPC_URL || "https://mainnet.optimism.io"),
  },
  baseSepolia: {
    chainId: 84532,
    transport: http(process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org"),
  },
  sepolia: {
    chainId: 11155111,
    transport: http(process.env.SEPOLIA_RPC_URL || "https://sepolia.infura.io/v3/demo"),
  },
};

// Contract addresses per network (from deployment configurations)
const contracts = {
  baseSepolia: {
    btcVaultToken: "0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a",
    btcVaultStrategy: "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8",
    startBlock: 19500000,
  },
  // Add other network contracts as they are deployed
  // ethereum: {
  //   btcVaultToken: "TBD",
  //   btcVaultStrategy: "TBD", 
  //   startBlock: 0,
  // },
  // base: {
  //   btcVaultToken: "TBD",
  //   btcVaultStrategy: "TBD",
  //   startBlock: 0,
  // },
  // arbitrum: {
  //   btcVaultToken: "TBD", 
  //   btcVaultStrategy: "TBD",
  //   startBlock: 0,
  // },
  // optimism: {
  //   btcVaultToken: "TBD",
  //   btcVaultStrategy: "TBD",
  //   startBlock: 0,
  // },
};

// Get enabled networks from environment or default to baseSepolia
const enabledNetworks = (process.env.PONDER_ENABLED_NETWORKS || "baseSepolia").split(',').map(n => n.trim());

// Build dynamic network and contract configurations
const activeNetworks: Record<string, any> = {};
const activeContracts: Record<string, any> = {};

for (const networkName of enabledNetworks) {
  if (networks[networkName] && contracts[networkName]) {
    const networkKey = networkName as keyof typeof networks;
    const contractKey = networkName as keyof typeof contracts;
    
    activeNetworks[networkName] = networks[networkKey];
    
    // Add contracts for this network
    activeContracts[`BtcVaultToken_${networkName}`] = {
      network: networkName,
      abi: BtcVaultTokenAbi as any,
      address: contracts[contractKey].btcVaultToken as `0x${string}`,
      startBlock: contracts[contractKey].startBlock,
    };
    
    activeContracts[`BtcVaultStrategy_${networkName}`] = {
      network: networkName,
      abi: BtcVaultStrategyAbi as any,
      address: contracts[contractKey].btcVaultStrategy as `0x${string}`,
      startBlock: contracts[contractKey].startBlock,
    };
  } else if (networks[networkName]) {
    console.warn(`Network ${networkName} is enabled but has no contract configuration. Skipping.`);
  } else {
    console.warn(`Unknown network ${networkName} in PONDER_ENABLED_NETWORKS. Skipping.`);
  }
}

export default createConfig({
  networks: activeNetworks,
  contracts: activeContracts,
  database: process.env.PONDER_DATABASE_URL || process.env.DATABASE_URL
    ? {
        kind: "postgres" as const,
        connectionString: process.env.PONDER_DATABASE_URL || process.env.DATABASE_URL,
      }
    : {
        kind: "sqlite" as const,
        // Fall back to SQLite if no database URL is provided
      },
  options: {
    port: parseInt(process.env.PORT || "42069"),
  },
});
