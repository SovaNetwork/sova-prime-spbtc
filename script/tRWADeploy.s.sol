// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {MockERC20} from "../src/token/MockERC20.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";

contract tRWADeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock USD token
        MockERC20 usdToken = new MockERC20("Mock USD", "USDC", 6);

        // Mint tokens to deployer for testing
        usdToken.mint(deployer, 1_000_000_000); // 1,000 USDC with 6 decimals

        // Deploy tRWA Factory
        tRWAFactory factory = new tRWAFactory();

        // Allow USD token as an asset
        factory.setAsset(address(usdToken), true);

        // Deploy KYC Rules with default deny
        KycRules kycRules = new KycRules(deployer, false);

        // Add this rule to allowed rules in factory
        factory.setRule(address(kycRules), true);

        // Allow the deployer address in KYC rules
        kycRules.allowAddress(deployer);

        // Deploy Price Oracle Reporter with initial price of 1 USD (assuming 6 decimals)
        uint256 initialPrice = 1_000_000; // $1.00 with 6 decimals
        PriceOracleReporter priceOracle = new PriceOracleReporter(initialPrice, deployer);

        // Deploy Strategy with the reporter
        ReportedStrategy strategy = new ReportedStrategy(
            deployer,
            deployer,
            address(usdToken),
            address(priceOracle)
        );

        // Deploy the tRWA token through the factory
        address tRWAToken = factory.deployToken(
            "Fountfi Sample Fund",
            "FUND",
            address(usdToken),
            address(strategy),
            address(kycRules)
        );

        // Log deployed contract addresses
        console.log("Deployed contracts:");
        console.log("Mock USD Token:", address(usdToken));
        console.log("tRWA Factory:", address(factory));
        console.log("KYC Rules:", address(kycRules));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("Reported Strategy:", address(strategy));
        console.log("tRWA Token:", tRWAToken);

        vm.stopBroadcast();
    }
}
