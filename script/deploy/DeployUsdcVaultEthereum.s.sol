// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SovaPrimeUsdStrategy} from "../../src/strategy/SovaPrimeUsdStrategy.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";

/**
 * @title DeployUsdcVaultEthereum
 * @notice Deployment script for USDC vault on Ethereum mainnet
 */
contract DeployUsdcVaultEthereum is Script {
    // Ethereum Mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    struct DeploymentOutput {
        address strategy;
        address token;
        address reporter;
        address roleManager;
        uint256 deployedBlock;
        uint256 timestamp;
    }

    function run() external returns (address strategy, address token) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get RoleManager address from environment (must be deployed first)
        address roleManager = vm.envAddress("ROLE_MANAGER_ADDRESS");

        console2.log("Deployer address:", deployer);
        console2.log("RoleManager address:", roleManager);
        console2.log("Deploying USDC Vault to Ethereum Mainnet");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PriceOracleReporter
        console2.log("\n1. Deploying PriceOracleReporter...");
        PriceOracleReporter reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1, 18 decimals for precision)
            deployer, // Updater
            100, // Max deviation per time period (1%)
            86400 // Time period (24 hours)
        );
        console2.log("   PriceOracleReporter deployed at:", address(reporter));

        // 2. Deploy SovaPrimeUsdStrategy
        console2.log("\n2. Deploying SovaPrimeUsdStrategy...");
        SovaPrimeUsdStrategy usdcStrategy = new SovaPrimeUsdStrategy();
        console2.log("   Strategy deployed at:", address(usdcStrategy));

        // 3. Initialize the strategy
        console2.log("\n3. Initializing strategy...");
        bytes memory initData = abi.encode(address(reporter));
        usdcStrategy.initialize(
            "Sova Prime USD",
            "spUSD",
            roleManager,
            deployer, // manager
            USDC,
            6, // USDC decimals
            initData
        );
        console2.log("   Strategy initialized");

        // 4. Get the auto-deployed token address
        token = usdcStrategy.sToken();
        console2.log("   Token auto-deployed at:", token);

        vm.stopBroadcast();

        // Save deployment output
        DeploymentOutput memory output = DeploymentOutput({
            strategy: address(usdcStrategy),
            token: token,
            reporter: address(reporter),
            roleManager: roleManager,
            deployedBlock: block.number,
            timestamp: block.timestamp
        });

        saveDeploymentOutput(output);

        // Log deployment summary
        console2.log("\n=== Ethereum USD Vault Deployment Summary ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Strategy (Sova Prime USD Strategy):", address(usdcStrategy));
        console2.log("Token (spUSD):", token);
        console2.log("PriceOracleReporter:", address(reporter));
        console2.log("Asset: USDC", USDC);
        console2.log("Decimals: 6");
        console2.log("Block Number:", block.number);
        console2.log("=============================================\n");

        return (address(usdcStrategy), token);
    }

    function saveDeploymentOutput(DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/ethereum-usdc-vault.json");

        string memory json = "deployment";
        vm.serializeAddress(json, "strategy", output.strategy);
        vm.serializeAddress(json, "token", output.token);
        vm.serializeAddress(json, "reporter", output.reporter);
        vm.serializeAddress(json, "roleManager", output.roleManager);
        vm.serializeUint(json, "deployedBlock", output.deployedBlock);
        string memory finalJson = vm.serializeUint(json, "timestamp", output.timestamp);

        vm.writeJson(finalJson, path);
        console2.log("Deployment output saved to:", path);
    }
}
