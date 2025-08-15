// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";
import {DeploymentConfig} from "../helpers/DeploymentConfig.sol";
import {DeploymentAddresses} from "../helpers/DeploymentAddresses.sol";

contract DeployReporter is Script {
    DeploymentConfig public config;
    DeploymentAddresses public addresses;

    function run() external returns (address reporter) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;

        config = new DeploymentConfig();
        addresses = new DeploymentAddresses();

        DeploymentConfig.NetworkConfig memory networkConfig = config.getNetworkConfig(chainId);
        DeploymentAddresses.Addresses memory deployedAddresses = addresses.getDeployment(chainId);

        require(deployedAddresses.roleManager != address(0), "RoleManager not deployed");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying PriceOracleReporter to chain:", chainId);
        console.log("Using RoleManager:", deployedAddresses.roleManager);
        console.log("Initial NAV:", networkConfig.initialNav);

        // Deploy PriceOracleReporter
        reporter = address(
            new PriceOracleReporter(
                networkConfig.initialNav,
                networkConfig.priceOracleUpdater,
                100, // 1% max deviation per period
                300 // 5 minutes period
            )
        );
        console.log("PriceOracleReporter deployed at:", reporter);

        vm.stopBroadcast();

        // Update deployment addresses
        deployedAddresses.reporter = reporter;

        vm.broadcast(deployerPrivateKey);
        addresses.saveDeployment(chainId, deployedAddresses);

        console.log("\n=== Reporter Deployment Complete ===");
        console.log("PriceOracleReporter:", reporter);
        console.log("Initial NAV:", networkConfig.initialNav);

        return reporter;
    }
}
