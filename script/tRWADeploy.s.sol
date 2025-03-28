// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {ItRWA} from "../src/interfaces/ItRWA.sol";
import {TransferApproval} from "../src/token/TransferApproval.sol";

contract tRWADeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory first
        tRWAFactory factory = new tRWAFactory();
        console.log("tRWAFactory deployed at:", address(factory));

        // Create mock addresses for subscription manager and underlying asset
        address subscriptionManager = address(123);
        address underlyingAsset = address(456);

        // Deploy a sample token first using manual constructor
        // We need this to pass to the Oracle
        ItRWA.ConfigurationStruct memory config = ItRWA.ConfigurationStruct({
            admin: msg.sender,
            priceAuthority: msg.sender, // Temporary, will be updated
            subscriptionManager: subscriptionManager,
            underlyingAsset: underlyingAsset
        });

        tRWA sampleToken = new tRWA(
            "Sample Token For Oracle",
            "STO",
            config
        );
        console.log("Sample token deployed at:", address(sampleToken));

        // Deploy the oracle with the token reference
        NavOracle oracle = new NavOracle(address(sampleToken), 1e18);
        console.log("NavOracle deployed at:", address(oracle));

        // Deploy compliance module with 100 token transfer limit
        TransferApproval compliance = new TransferApproval(100e18, true);
        console.log("TransferApproval deployed at:", address(compliance));

        // Set approvals in the factory
        factory.setOracleApproval(address(oracle), true);
        factory.setSubscriptionManagerApproval(subscriptionManager, true);
        factory.setUnderlyingAssetApproval(underlyingAsset, true);
        factory.setTransferApprovalApproval(address(compliance), true);
        // Also approve address(0) for transfer approval to support tokens without compliance
        factory.setTransferApprovalApproval(address(0), true);
        console.log("Approvals set in factory");

        // Deploy a sample token with compliance enabled
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            address(oracle),
            subscriptionManager,
            underlyingAsset,
            address(compliance)
        );
        console.log("Sample token deployed at:", tokenAddress);

        // Deploy another token without compliance
        address token2Address = factory.deployToken(
            "Tokenized Infrastructure Fund",
            "TIF",
            address(oracle),
            subscriptionManager,
            underlyingAsset,
            address(0)
        );
        console.log("Second token deployed at:", token2Address);

        vm.stopBroadcast();
    }
}

contract tRWASimulationScript is Script {
    function run() public {
        // For simulation and testing purposes
        // Addresses are placeholders and should be replaced with actual deployed addresses
        address oracleAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address tokenAddress = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        // Simulation uses placeholders
        NavOracle oracle = NavOracle(oracleAddress);
        tRWA token = tRWA(tokenAddress);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // In a real simulation, you would update the underlying value
        oracle.updateUnderlyingValue(1.05e18, "Test Update");
        console.log("Updated underlying value per token");

        vm.stopBroadcast();
    }
}