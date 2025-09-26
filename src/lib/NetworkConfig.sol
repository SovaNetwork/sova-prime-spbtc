// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

/**
 * @title NetworkConfig
 * @notice Library for managing network-specific configurations
 * @dev Provides chain-specific settings for multi-network deployments
 */
library NetworkConfig {
    struct Network {
        uint256 chainId;
        string name;
        address btcOracle;
        uint256 confirmations;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
    }

    struct CollateralConfig {
        address tokenAddress;
        string symbol;
        uint8 decimals;
        bool isActive;
    }

    struct DeploymentConfig {
        address initialReporter;
        address manager;
        address admin;
        uint256 depositLimit;
        uint256 withdrawalLimit;
        uint256 minDeposit;
    }

    error UnsupportedNetwork(uint256 chainId);
    error InvalidCollateral(address token);

    /**
     * @notice Get network configuration for current chain
     * @param chainId The chain ID to get configuration for
     * @return Network configuration struct
     */
    function getNetworkConfig(uint256 chainId) internal pure returns (Network memory) {
        if (chainId == 1) {
            // Ethereum Mainnet
            return Network({
                chainId: 1,
                name: "Ethereum Mainnet",
                btcOracle: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
                confirmations: 2,
                maxFeePerGas: 50 gwei,
                maxPriorityFeePerGas: 2 gwei
            });
        } else if (chainId == 42161) {
            // Arbitrum One
            return Network({
                chainId: 42161,
                name: "Arbitrum One",
                btcOracle: 0x6ce185860a4963106506C203335A2910413708e9,
                confirmations: 1,
                maxFeePerGas: 1 gwei,
                maxPriorityFeePerGas: 0
            });
        } else if (chainId == 10) {
            // Optimism
            return Network({
                chainId: 10,
                name: "Optimism",
                btcOracle: 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593,
                confirmations: 1,
                maxFeePerGas: 1 gwei,
                maxPriorityFeePerGas: 0.001 gwei
            });
        } else if (chainId == 8453) {
            // Base
            return Network({
                chainId: 8453,
                name: "Base",
                btcOracle: 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F,
                confirmations: 1,
                maxFeePerGas: 1 gwei,
                maxPriorityFeePerGas: 0.001 gwei
            });
        } else if (chainId == 137) {
            // Polygon
            return Network({
                chainId: 137,
                name: "Polygon",
                btcOracle: 0xc907E116054Ad103354f2D350FD2514433D57F6f,
                confirmations: 3,
                maxFeePerGas: 50 gwei,
                maxPriorityFeePerGas: 30 gwei
            });
        } else if (chainId == 43114) {
            // Avalanche C-Chain
            return Network({
                chainId: 43114,
                name: "Avalanche C-Chain",
                btcOracle: 0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743,
                confirmations: 1,
                maxFeePerGas: 50 gwei,
                maxPriorityFeePerGas: 2 gwei
            });
        } else if (chainId == 84532) {
            // Base Sepolia
            return Network({
                chainId: 84532,
                name: "Base Sepolia",
                btcOracle: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,
                confirmations: 1,
                maxFeePerGas: 1 gwei,
                maxPriorityFeePerGas: 0.001 gwei
            });
        } else if (chainId == 11155111) {
            // Sepolia
            return Network({
                chainId: 11155111,
                name: "Sepolia Testnet",
                btcOracle: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                confirmations: 1,
                maxFeePerGas: 50 gwei,
                maxPriorityFeePerGas: 2 gwei
            });
        } else {
            revert UnsupportedNetwork(chainId);
        }
    }

    /**
     * @notice Get collateral tokens for a specific network
     * @param chainId The chain ID to get collaterals for
     * @return Array of collateral configurations
     */
    function getCollaterals(uint256 chainId) internal pure returns (CollateralConfig[] memory) {
        if (chainId == 1) {
            // Ethereum Mainnet
            CollateralConfig[] memory collaterals = new CollateralConfig[](3);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
                symbol: "WBTC",
                decimals: 8,
                isActive: true
            });
            collaterals[1] = CollateralConfig({
                tokenAddress: 0x18084fbA666a33d37592fA2633fD49a74DD93a88,
                symbol: "tBTC",
                decimals: 18,
                isActive: true
            });
            collaterals[2] = CollateralConfig({
                tokenAddress: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
                symbol: "cbBTC",
                decimals: 8,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 42161) {
            // Arbitrum One
            CollateralConfig[] memory collaterals = new CollateralConfig[](2);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
                symbol: "WBTC",
                decimals: 8,
                isActive: true
            });
            collaterals[1] = CollateralConfig({
                tokenAddress: 0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40,
                symbol: "tBTC",
                decimals: 18,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 10) {
            // Optimism
            CollateralConfig[] memory collaterals = new CollateralConfig[](2);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0x68f180fcCe6836688e9084f035309E29Bf0A2095,
                symbol: "WBTC",
                decimals: 8,
                isActive: true
            });
            collaterals[1] = CollateralConfig({
                tokenAddress: 0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40,
                symbol: "tBTC",
                decimals: 18,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 8453) {
            // Base
            CollateralConfig[] memory collaterals = new CollateralConfig[](1);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
                symbol: "cbBTC",
                decimals: 8,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 137) {
            // Polygon
            CollateralConfig[] memory collaterals = new CollateralConfig[](1);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
                symbol: "WBTC",
                decimals: 8,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 43114) {
            // Avalanche
            CollateralConfig[] memory collaterals = new CollateralConfig[](2);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0x50b7545627a5162F82A992c33b87aDc75187B218,
                symbol: "WBTC",
                decimals: 8,
                isActive: true
            });
            collaterals[1] = CollateralConfig({
                tokenAddress: 0x152b9d0FdC40C096757F570A51E494bd4b943E50,
                symbol: "BTC.b",
                decimals: 8,
                isActive: true
            });
            return collaterals;
        } else if (chainId == 84532) {
            // Base Sepolia
            CollateralConfig[] memory collaterals = new CollateralConfig[](3);
            collaterals[0] = CollateralConfig({
                tokenAddress: 0xe44b2870eFcd6Bb3C9305808012621f438e9636D,
                symbol: "WBTC",
                decimals: 18,
                isActive: true
            });
            collaterals[1] = CollateralConfig({
                tokenAddress: 0xd3f2D7b0674a72299E8f37737cC744E370613ec0,
                symbol: "tBTC",
                decimals: 18,
                isActive: true
            });
            collaterals[2] = CollateralConfig({
                tokenAddress: 0xD04B3bD2562509515DeaA4B8341d759F2556ed78,
                symbol: "cbBTC",
                decimals: 18,
                isActive: true
            });
            return collaterals;
        } else {
            revert UnsupportedNetwork(chainId);
        }
    }

    /**
     * @notice Check if a network is supported
     * @param chainId The chain ID to check
     * @return true if network is supported, false otherwise
     */
    function isNetworkSupported(uint256 chainId) internal pure returns (bool) {
        return chainId == 1 // Ethereum
            || chainId == 42161 // Arbitrum
            || chainId == 10 // Optimism
            || chainId == 8453 // Base
            || chainId == 137 // Polygon
            || chainId == 43114 // Avalanche
            || chainId == 84532 // Base Sepolia
            || chainId == 11155111; // Sepolia
    }

    /**
     * @notice Get the network name for a chain ID
     * @param chainId The chain ID
     * @return The network name
     */
    function getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "Ethereum Mainnet";
        if (chainId == 42161) return "Arbitrum One";
        if (chainId == 10) return "Optimism";
        if (chainId == 8453) return "Base";
        if (chainId == 137) return "Polygon";
        if (chainId == 43114) return "Avalanche C-Chain";
        if (chainId == 84532) return "Base Sepolia";
        if (chainId == 11155111) return "Sepolia Testnet";
        revert UnsupportedNetwork(chainId);
    }

    /**
     * @notice Get default deployment configuration
     * @return Default deployment settings
     */
    function getDefaultDeploymentConfig() internal pure returns (DeploymentConfig memory) {
        return DeploymentConfig({
            initialReporter: address(0),
            manager: address(0),
            admin: address(0),
            depositLimit: 1000 * 1e18,
            withdrawalLimit: 100 * 1e18,
            minDeposit: 0.001 * 1e18
        });
    }
}
