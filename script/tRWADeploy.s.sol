// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {TransferApproval} from "../src/token/TransferApproval.sol";

contract tRWADeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the oracle
        NavOracle oracle = new NavOracle();
        console2.log("NavOracle deployed at:", address(oracle));

        // Deploy compliance module with 100 token transfer limit
        TransferApproval compliance = new TransferApproval(100e18, true);
        console2.log("TransferApproval deployed at:", address(compliance));

        // Create mock addresses for subscription manager and underlying asset
        address subscriptionManager = address(this);
        address underlyingAsset = address(0xDADA);

        // Deploy the factory
        tRWAFactory factory = new tRWAFactory(address(oracle), subscriptionManager, underlyingAsset);
        console2.log("tRWAFactory deployed at:", address(factory));

        // Set compliance module in factory
        factory.setTransferApproval(address(compliance));
        console2.log("Compliance module set in factory");

        // Deploy a sample token with compliance enabled
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            1e18 // $1.00 per share
        );
        console2.log("Sample token deployed at:", tokenAddress);

        // Deploy another token without compliance
        address token2Address = factory.deployToken(
            "Tokenized Infrastructure Fund",
            "TIF",
            1.5e18 // $1.50 per share
        );
        console2.log("Second token deployed at:", token2Address);

        vm.stopBroadcast();
    }
}

contract tRWASimulationScript is Script {
    function run() public {
        // For simulation and testing purposes
        // Addresses are placeholders and should be replaced with actual deployed addresses
        address oracleAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address factoryAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        address tokenAddress = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;

        // Simulate NAV update
        NavOracle oracle = NavOracle(oracleAddress);
        tRWAFactory factory = tRWAFactory(factoryAddress);
        tRWA token = tRWA(tokenAddress);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Update underlying value to $1.05 per token
        oracle.updateUnderlyingValue(tokenAddress, 1.05e18);
        console2.log("Updated underlying value per token:", token.underlyingPerToken());

        // Mint some tokens to an address (replace with actual address)
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        token.deposit(1000e18, recipient);
        console2.log("Minted 1000 tokens to:", recipient);
        console2.log("USD value of holdings:", token.getUsdValue(1000e18));

        vm.stopBroadcast();
    }
}