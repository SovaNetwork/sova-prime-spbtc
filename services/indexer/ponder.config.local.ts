import { createConfig } from "@ponder/core";
import { http } from "viem";
import BtcVaultTokenAbi from "./abis/BtcVaultToken.json";
import BtcVaultStrategyAbi from "./abis/BtcVaultStrategy.json";

// Network configuration
const networks = {
  baseSepolia: {
    chainId: 84532,
    transport: http(process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org"),
  },
};

// Contract addresses (from deployment)
const contracts = {
  baseSepolia: {
    btcVaultToken: "0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a",
    btcVaultStrategy: "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8",
    startBlock: 19500000,
  },
};

const activeNetwork = "baseSepolia";
const networkConfig = networks[activeNetwork];
const contractConfig = contracts[activeNetwork];

export default createConfig({
  networks: {
    [activeNetwork]: networkConfig,
  },
  contracts: {
    BtcVaultToken: {
      network: activeNetwork,
      abi: BtcVaultTokenAbi as any,
      address: contractConfig.btcVaultToken as \`0x\${string}\`,
      startBlock: contractConfig.startBlock,
    },
    BtcVaultStrategy: {
      network: activeNetwork,
      abi: BtcVaultStrategyAbi as any,
      address: contractConfig.btcVaultStrategy as \`0x\${string}\`,
      startBlock: contractConfig.startBlock,
    },
  },
  database: {
    kind: "sqlite",
  },
});
