// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BtcVaultStrategy} from "../../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";
import {RoleManager} from "../../src/auth/RoleManager.sol";
import {Registry} from "../../src/registry/Registry.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title DeployBtcVault
 * @notice Deployment script for the simplified BTC vault architecture
 * @dev Deploys BtcVaultStrategy which auto-deploys its BtcVaultToken
 *      Reads configuration from deployment.config.json
 */
contract DeployBtcVault is Script {
    // Deployment configuration structure
    struct DeploymentConfig {
        address roleManager;
        address sovaBTC;
        address wBTC;
        address tBTC;
        uint256 initialLiquidity;
        bool verifyContracts;
    }

    // Deployed addresses to output
    struct DeploymentOutput {
        address strategy;
        address token;
        address reporter;
        uint256 deployedBlock;
        uint256 timestamp;
    }

    function run() external returns (address strategy, address token) {
        // Determine network
        string memory network = vm.envOr("NETWORK", string("baseSepolia"));
        console2.log("Deploying to network:", network);

        // Load configuration
        DeploymentConfig memory config = loadConfig(network);

        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PriceOracleReporter for the strategy
        PriceOracleReporter reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            deployer, // Updater
            100, // Max deviation per time period (1%)
            86400 // Time period (24 hours)
        );
        console2.log("PriceOracleReporter deployed at:", address(reporter));

        // 2. Deploy and initialize BtcVaultStrategy
        // This will automatically deploy BtcVaultToken
        BtcVaultStrategy btcStrategy = new BtcVaultStrategy();

        // Initialize with reporter address encoded
        bytes memory initData = abi.encode(address(reporter));
        btcStrategy.initialize(
            "BTC Vault Strategy",
            "BTC-STRAT",
            config.roleManager,
            deployer, // manager
            config.sovaBTC,
            8, // sovaBTC decimals (BTC typically uses 8)
            initData
        );
        console2.log("BtcVaultStrategy deployed at:", address(btcStrategy));

        // 3. Get the auto-deployed token address
        address btcToken = btcStrategy.sToken();
        console2.log("BtcVaultToken auto-deployed at:", btcToken);

        // 4. Configure initial collateral types
        if (config.wBTC != address(0)) {
            btcStrategy.addCollateral(config.wBTC); // 8 decimals for BTC
            console2.log("Added WBTC as collateral:", config.wBTC);
        }

        if (config.tBTC != address(0)) {
            btcStrategy.addCollateral(config.tBTC); // 8 decimals for BTC
            console2.log("Added tBTC as collateral:", config.tBTC);
        }

        // 5. Add initial sovaBTC liquidity if desired
        if (config.initialLiquidity > 0) {
            // Check balance first
            uint256 balance = IERC20(config.sovaBTC).balanceOf(deployer);
            require(balance >= config.initialLiquidity, "Insufficient sovaBTC balance");

            IERC20(config.sovaBTC).approve(address(btcStrategy), config.initialLiquidity);
            btcStrategy.addLiquidity(config.initialLiquidity);
            console2.log("Added initial liquidity:", config.initialLiquidity);
        }

        vm.stopBroadcast();

        // Save deployment output
        DeploymentOutput memory output = DeploymentOutput({
            strategy: address(btcStrategy),
            token: btcToken,
            reporter: address(reporter),
            deployedBlock: block.number,
            timestamp: block.timestamp
        });

        saveDeploymentOutput(network, output);

        // Log deployment summary
        console2.log("\n=== BTC Vault Deployment Summary ===");
        console2.log("Network:", network);
        console2.log("BtcVaultStrategy:", address(btcStrategy));
        console2.log("BtcVaultToken:", btcToken);
        console2.log("PriceOracleReporter:", address(reporter));
        console2.log("Block Number:", block.number);
        console2.log("Architecture: Simplified 2-contract system");
        console2.log("Pattern: ManagedWithdrawRWAStrategy");
        console2.log("=====================================\n");

        // Verify contracts if configured
        if (config.verifyContracts) {
            console2.log("Run verification with:");
            console2.log("forge verify-contract", address(btcStrategy), "BtcVaultStrategy");
            console2.log("forge verify-contract", btcToken, "BtcVaultToken");
            console2.log("forge verify-contract", address(reporter), "PriceOracleReporter");
        }

        return (address(btcStrategy), btcToken);
    }

    function loadConfig(string memory network) internal view returns (DeploymentConfig memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployment.config.json");
        string memory json = vm.readFile(path);

        // Parse JSON based on network
        string memory key = string.concat(".", network);

        DeploymentConfig memory config;
        config.roleManager = vm.parseJsonAddress(json, string.concat(key, ".contracts.roleManager"));
        config.sovaBTC = vm.parseJsonAddress(json, string.concat(key, ".contracts.sovaBTC"));
        config.wBTC = vm.parseJsonAddress(json, string.concat(key, ".contracts.wBTC"));
        config.tBTC = vm.parseJsonAddress(json, string.concat(key, ".contracts.tBTC"));
        config.initialLiquidity = vm.parseJsonUint(json, string.concat(key, ".deployment.initialLiquidity"));
        config.verifyContracts = vm.parseJsonBool(json, string.concat(key, ".verification.verifyContracts"));

        return config;
    }

    function saveDeploymentOutput(string memory network, DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/");
        path = string.concat(path, network);
        path = string.concat(path, "-btc-vault.json");

        // Create JSON output
        string memory json = "deployment";
        vm.serializeAddress(json, "strategy", output.strategy);
        vm.serializeAddress(json, "token", output.token);
        vm.serializeAddress(json, "reporter", output.reporter);
        vm.serializeUint(json, "deployedBlock", output.deployedBlock);
        string memory finalJson = vm.serializeUint(json, "timestamp", output.timestamp);

        // Write to file
        vm.writeJson(finalJson, path);
        console2.log("Deployment output saved to:", path);
    }
}
