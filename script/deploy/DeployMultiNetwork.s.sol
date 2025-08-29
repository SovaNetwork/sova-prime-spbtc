// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BtcVaultStrategy} from "../../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";
import {DeploymentRegistry} from "../../src/DeploymentRegistry.sol";
import {NetworkConfig} from "../../src/lib/NetworkConfig.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title DeployMultiNetwork
 * @notice Universal deployment script for BTC Vault across multiple networks
 * @dev Automatically detects network and loads appropriate configuration
 */
contract DeployMultiNetwork is Script {
    // Deployment artifacts
    BtcVaultStrategy public strategy;
    BtcVaultToken public token;
    PriceOracleReporter public oracle;
    DeploymentRegistry public registry;

    // Network detection
    uint256 public chainId;
    NetworkConfig.Network public networkConfig;

    // Version info
    string public constant VERSION = "1.0.0";

    // Events for logging
    event NetworkDetected(uint256 chainId, string name);
    event ContractDeployed(string contractName, address contractAddress);
    event CollateralAdded(address token, string symbol);
    event DeploymentRegistered(uint256 deploymentId);

    error NetworkNotSupported(uint256 chainId);
    error DeploymentFailed(string reason);
    error InvalidConfiguration();

    function run() external {
        // Detect network
        chainId = block.chainid;
        console2.log("Detected Chain ID:", chainId);

        // Validate network support
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            revert NetworkNotSupported(chainId);
        }

        // Load network configuration
        networkConfig = NetworkConfig.getNetworkConfig(chainId);
        NetworkConfig.CollateralConfig[] memory collaterals = NetworkConfig.getCollaterals(chainId);

        console2.log("Network:", networkConfig.name);
        console2.log("Oracle Address:", networkConfig.btcOracle);
        console2.log("Collaterals Count:", collaterals.length);

        // Start deployment
        vm.startBroadcast();

        // Deploy contracts
        _deployContracts();

        // Configure collaterals
        _configureCollaterals();

        // Register deployment if registry exists
        _registerDeployment();

        vm.stopBroadcast();

        // Print deployment summary
        _printSummary();
    }

    function _deployContracts() internal {
        console2.log("\n=== Deploying Contracts ===");

        // Get deployment config
        NetworkConfig.DeploymentConfig memory config = NetworkConfig.getDefaultDeploymentConfig();

        // Override with environment variables if available
        address deployer = msg.sender;
        if (config.admin == address(0)) {
            config.admin = deployer;
        }
        if (config.manager == address(0)) {
            config.manager = deployer;
        }
        if (config.initialReporter == address(0)) {
            config.initialReporter = deployer;
        }

        // Deploy Oracle with default parameters
        console2.log("Deploying PriceOracleReporter...");
        oracle = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            config.initialReporter,
            1000, // Max deviation per time period (10%)
            300 // Time period (5 minutes)
        );
        console2.log("Oracle deployed at:", address(oracle));

        // Deploy Strategy
        console2.log("Deploying BtcVaultStrategy...");
        strategy = new BtcVaultStrategy();
        console2.log("Strategy deployed at:", address(strategy));

        // Deploy Token - get sovaBTC address from first collateral or use zero for testnet
        NetworkConfig.CollateralConfig[] memory collaterals = NetworkConfig.getCollaterals(chainId);
        address sovaBTC = collaterals.length > 0 ? collaterals[0].tokenAddress : address(0);

        console2.log("Deploying BtcVaultToken...");
        token = new BtcVaultToken("spBTC", "spBTC", sovaBTC, address(strategy));
        console2.log("Token deployed at:", address(token));

        // Initialize strategy
        console2.log("Initializing strategy...");
        bytes memory initData = abi.encode(address(oracle));
        strategy.initialize("BTC Vault Strategy", "BTC-VAULT", config.admin, config.manager, sovaBTC, 8, initData);

        // Roles are handled during initialization, no need to grant separately

        console2.log("\nContracts deployed successfully!");
    }

    function _configureCollaterals() internal {
        console2.log("\n=== Configuring Collaterals ===");

        NetworkConfig.CollateralConfig[] memory collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < collaterals.length; i++) {
            NetworkConfig.CollateralConfig memory collateral = collaterals[i];

            // Skip if token address is zero (not available on this network)
            if (collateral.tokenAddress == address(0)) {
                console2.log("Skipping", collateral.symbol, "- not available on this network");
                continue;
            }

            console2.log("Adding collateral:", collateral.symbol);
            console2.log("  Address:", collateral.tokenAddress);
            console2.log("  Decimals:", collateral.decimals);

            try strategy.addCollateral(collateral.tokenAddress) {
                console2.log("  Status: Added successfully");
            } catch Error(string memory reason) {
                console2.log("  Status: Failed -", reason);
            } catch {
                console2.log("  Status: Failed - unknown error");
            }
        }

        console2.log("\nCollateral configuration complete!");
    }

    function _registerDeployment() internal {
        console2.log("\n=== Registering Deployment ===");

        // Check if registry is deployed on this network
        // For now, we'll skip if no registry exists
        address registryAddress = _getRegistryAddress();

        if (registryAddress == address(0)) {
            console2.log("No registry configured for this network, skipping registration");
            return;
        }

        registry = DeploymentRegistry(registryAddress);

        try registry.registerDeployment(
            chainId, address(strategy), address(token), address(oracle), VERSION, networkConfig.name
        ) returns (uint256 deploymentId) {
            console2.log("Deployment registered with ID:", deploymentId);
        } catch Error(string memory reason) {
            console2.log("Registration failed:", reason);
        } catch {
            console2.log("Registration failed: unknown error");
        }
    }

    function _getRegistryAddress() internal view returns (address) {
        // This would typically load from a config file or environment variable
        // For now, return zero address if not configured
        // In production, this would read from deployment.multinetwork.config.json
        return address(0);
    }

    function _printSummary() internal view {
        console2.log("\n========================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("Network:", networkConfig.name);
        console2.log("Chain ID:", chainId);
        console2.log("Version:", VERSION);
        console2.log("----------------------------------------");
        console2.log("Contracts:");
        console2.log("  Oracle:", address(oracle));
        console2.log("  Strategy:", address(strategy));
        console2.log("  Token:", address(token));
        console2.log("----------------------------------------");
        console2.log("Collaterals:");
        NetworkConfig.CollateralConfig[] memory collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i].tokenAddress != address(0)) {
                console2.log(" ", collaterals[i].symbol, ":", collaterals[i].tokenAddress);
            }
        }
        console2.log("========================================");
        console2.log("\nDeployment complete!");
        console2.log("\nTo verify contracts, run:");
        console2.log("forge verify-contract <address> <contract> --chain", chainId);
    }

    /**
     * @notice Deploy to a specific network by providing RPC URL
     * @dev This function can be called directly for testing
     */
    function deployToNetwork(string memory rpcUrl) public {
        // Set RPC URL
        vm.createSelectFork(rpcUrl);

        // Run deployment
        this.run();
    }

    /**
     * @notice Batch deploy to multiple networks
     * @dev Requires RPC URLs to be configured in environment
     */
    function deployToAllNetworks() public {
        string[8] memory networks =
            ["ethereum", "arbitrum", "optimism", "base", "polygon", "avalanche", "base-sepolia", "sepolia"];

        for (uint256 i = 0; i < networks.length; i++) {
            string memory envVar = string(abi.encodePacked(_toUpperCase(networks[i]), "_RPC_URL"));

            string memory rpcUrl = vm.envString(envVar);

            if (bytes(rpcUrl).length > 0) {
                console2.log("\n\nDeploying to", networks[i], "...");
                deployToNetwork(rpcUrl);
            } else {
                console2.log("\n\nSkipping", networks[i], "- no RPC URL configured");
            }
        }
    }

    function _toUpperCase(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);

        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            if (char >= 0x61 && char <= 0x7A) {
                result[i] = bytes1(uint8(char) - 32);
            } else if (char == 0x2D) {
                // hyphen to underscore
                result[i] = 0x5F;
            } else {
                result[i] = char;
            }
        }

        return string(result);
    }
}
