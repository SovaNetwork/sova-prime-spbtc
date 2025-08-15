import { createConfig } from "ponder";
import { getNetworkConfig, validateNetworkConfig } from "./src/config";
import MultiBTCVaultAbi from "./abis/MultiBTCVault.json";
import ManagedRedemptionQueueAbi from "./abis/ManagedRedemptionQueue.json";
import MultiCollateralRegistryAbi from "./abis/MultiCollateralRegistry.json";
import MultiCollateralStrategyAbi from "./abis/MultiCollateralStrategy.json";
import PriceOracleReporterAbi from "./abis/PriceOracleReporter.json";

// Get network configuration
const networkConfig = getNetworkConfig();

// Validate configuration for mainnet deployments
if (process.env.NODE_ENV === 'production') {
  validateNetworkConfig(networkConfig);
}

// Build chain configuration
const chainConfig: any = {
  id: networkConfig.chainId,
  rpc: networkConfig.rpcUrl,
};

// Build contracts configuration dynamically
const contractsConfig: any = {};

// Add Vault contract if configured
if (networkConfig.contracts.vault && networkConfig.contracts.vault !== '0x') {
  contractsConfig.MultiBTCVault = {
    chain: {
      id: networkConfig.chainId,
      rpc: networkConfig.rpcUrl,
    },
    abi: MultiBTCVaultAbi,
    address: networkConfig.contracts.vault,
    startBlock: networkConfig.startBlock,
  };
}

// Add Queue contract if configured
if (networkConfig.contracts.queue && networkConfig.contracts.queue !== '0x') {
  contractsConfig.ManagedRedemptionQueue = {
    chain: {
      id: networkConfig.chainId,
      rpc: networkConfig.rpcUrl,
    },
    abi: ManagedRedemptionQueueAbi,
    address: networkConfig.contracts.queue,
    startBlock: networkConfig.startBlock,
  };
}

// Add Registry contract if configured
if (networkConfig.contracts.registry && networkConfig.contracts.registry !== '0x') {
  contractsConfig.MultiCollateralRegistry = {
    chain: {
      id: networkConfig.chainId,
      rpc: networkConfig.rpcUrl,
    },
    abi: MultiCollateralRegistryAbi,
    address: networkConfig.contracts.registry,
    startBlock: networkConfig.startBlock,
  };
}

// Add Strategy contract if configured
if (networkConfig.contracts.strategy && networkConfig.contracts.strategy !== '0x') {
  contractsConfig.MultiCollateralStrategy = {
    chain: {
      id: networkConfig.chainId,
      rpc: networkConfig.rpcUrl,
    },
    abi: MultiCollateralStrategyAbi,
    address: networkConfig.contracts.strategy,
    startBlock: networkConfig.startBlock,
  };
}

// Add Price Oracle contract if configured
if (networkConfig.contracts.priceOracle && networkConfig.contracts.priceOracle !== '0x') {
  contractsConfig.PriceOracleReporter = {
    chain: {
      id: networkConfig.chainId,
      rpc: networkConfig.rpcUrl,
    },
    abi: PriceOracleReporterAbi,
    address: networkConfig.contracts.priceOracle,
    startBlock: networkConfig.startBlock,
  };
}

// Log configuration on startup
console.log('🚀 Ponder Indexer Configuration:');
console.log(`  Network: ${process.env.NETWORK || 'base-sepolia'}`);
console.log(`  Chain ID: ${networkConfig.chainId}`);
console.log(`  Start Block: ${networkConfig.startBlock}`);
console.log(`  Contracts:`, Object.keys(contractsConfig).join(', '));

export default createConfig({
  chains: {
    [process.env.NETWORK || 'baseSepolia']: chainConfig,
  },
  contracts: contractsConfig,
  database: {
    kind: "postgres",
    connectionString: process.env.DATABASE_URL,
  },
  options: {
    maxBlockRange: networkConfig.indexer.maxBlockRange,
    pollingInterval: networkConfig.indexer.pollingInterval,
  },
});