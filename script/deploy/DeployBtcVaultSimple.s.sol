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
 * @title DeployBtcVaultSimple
 * @notice Simple deployment script for the BTC vault architecture
 * @dev Deploys BtcVaultStrategy which auto-deploys its BtcVaultToken
 */
contract DeployBtcVaultSimple is Script {
    // Base Sepolia addresses
    address constant ROLE_MANAGER = 0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72;
    address constant REGISTRY = 0x6F0fecBC276de8fC69257065fE47C5a03d986394;
    address constant SOVABTC = 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9;
    address constant WBTC = 0xe44b2870eFcd6Bb3C9305808012621f438e9636D;
    address constant TBTC = 0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802;

    function run() external returns (address strategy, address token) {
        console2.log("Deploying BTC Vault to Base Sepolia");
        console2.log("=================================");

        uint256 deployerPrivateKey =
            vm.envOr("PRIVATE_KEY", uint256(0x95a18be97b616ea6a2c79e1a82090f66686f15548b6cbb621a6a6417677759d4));
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Price Oracle Reporter with constructor parameters
        console2.log("\n1. Deploying Price Oracle Reporter...");
        PriceOracleReporter reporter = new PriceOracleReporter(
            1e18, // initial price
            deployer, // updater
            500, // 5% max deviation
            3600 // 1 hour time period in seconds
        );
        console2.log("   Price Oracle Reporter deployed at:", address(reporter));

        // 2. Create a new BTC Vault Strategy
        console2.log("\n2. Creating BTC Vault Strategy...");
        BtcVaultStrategy btcStrategy = new BtcVaultStrategy();
        console2.log("   BTC Vault Strategy created at:", address(btcStrategy));

        // 3. Initialize the strategy
        console2.log("\n3. Initializing BTC Vault Strategy...");
        bytes memory initData = abi.encode(address(reporter));
        btcStrategy.initialize(
            "BTC Vault Token",
            "btcVault",
            ROLE_MANAGER,
            deployer, // manager
            SOVABTC, // liquidity token
            8, // decimals
            initData
        );
        console2.log("   Strategy initialized");

        // 4. Get the deployed token address
        token = btcStrategy.sToken();
        console2.log("   BTC Vault Token deployed at:", token);

        // 5. Add initial collateral support
        console2.log("\n4. Adding collateral support...");

        // Add WBTC support
        btcStrategy.addCollateral(WBTC);
        console2.log("   Added WBTC as collateral");

        // Add TBTC support
        btcStrategy.addCollateral(TBTC);
        console2.log("   Added TBTC as collateral");

        // Add sovaBTC support (already added during initialization, but let's ensure it)
        // btcStrategy.addCollateral(SOVABTC); // Skip this as it's already added
        console2.log("   sovaBTC already supported as collateral");

        // 6. Set reporter as updater
        console2.log("\n5. Setting up reporter permissions...");
        reporter.setUpdater(deployer, true);
        console2.log("   Deployer set as price updater");

        // 7. Log deployment summary
        console2.log("\n=================================");
        console2.log("Deployment Complete!");
        console2.log("=================================");
        console2.log("BTC Vault Strategy:", address(btcStrategy));
        console2.log("BTC Vault Token:", token);
        console2.log("Price Oracle Reporter:", address(reporter));
        console2.log("=================================");

        // Log deployment instructions
        console2.log("\nNext steps:");
        console2.log("1. Verify contracts on Etherscan");
        console2.log("2. Add initial sovaBTC liquidity to strategy");
        console2.log("3. Update frontend contract addresses");
        console2.log("4. Test deposit and withdrawal flows");

        vm.stopBroadcast();

        strategy = address(btcStrategy);

        // Save deployment addresses to file (for reference)
        string memory output = string.concat(
            '{"strategy":"',
            vm.toString(strategy),
            '","token":"',
            vm.toString(token),
            '","reporter":"',
            vm.toString(address(reporter)),
            '","block":',
            vm.toString(block.number),
            ',"timestamp":',
            vm.toString(block.timestamp),
            "}"
        );

        console2.log("\nDeployment output:", output);

        return (strategy, token);
    }
}
