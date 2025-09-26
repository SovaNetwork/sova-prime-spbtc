// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";
import {DeploymentAddresses} from "../helpers/DeploymentAddresses.sol";

contract UpdatePriceOracle is Script {
    DeploymentAddresses public addresses;

    function run() external {
        uint256 adminPrivateKey = vm.envUint("ADMIN_PRIVATE_KEY");
        uint256 chainId = block.chainid;
        uint256 newPrice = vm.envUint("NEW_PRICE"); // Price in 18 decimals

        addresses = new DeploymentAddresses();
        DeploymentAddresses.Addresses memory deployedAddresses = addresses.getDeployment(chainId);

        require(deployedAddresses.reporter != address(0), "Reporter not deployed");

        vm.startBroadcast(adminPrivateKey);

        console.log("Updating price oracle on chain:", chainId);
        console.log("Reporter address:", deployedAddresses.reporter);

        PriceOracleReporter reporter = PriceOracleReporter(deployedAddresses.reporter);

        uint256 currentPrice = reporter.getCurrentPrice();
        console.log("Current price:", currentPrice);
        console.log("New price:", newPrice);

        reporter.update(newPrice, "Admin update");

        uint256 updatedPrice = reporter.getCurrentPrice();
        console.log("Updated price:", updatedPrice);

        require(updatedPrice == newPrice, "Price update failed");

        vm.stopBroadcast();

        console.log("\n=== Price Update Complete ===");
        console.log("Price successfully updated from", currentPrice, "to", newPrice);
    }
}
