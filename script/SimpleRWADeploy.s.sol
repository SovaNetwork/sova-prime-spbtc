// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";

contract SimpleRWADeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock USD token
        MockERC20 usdToken = new MockERC20("Mock USD", "USDC", 6);

        // Mint tokens to deployer for testing
        usdToken.mint(deployer, 1_000_000_000); // 1,000 USDC with 6 decimals

        console.log("Mock USD Token deployed.");

        // Deploy Registry
        Registry registry = new Registry();

        console.log("Registry deployed.");

        // Allow USD token as an asset
        registry.setAsset(address(usdToken), true);

        // Deploy KYC Rules with default deny
        KycRules kycRules = new KycRules(deployer, false);

        console.log("KYC Rules deployed.");

        // Add this rule to allowed rules in registry
        registry.setRules(address(kycRules), true);

        // Allow the deployer address in KYC rules
        kycRules.allowAddress(deployer);

        console.log("Deployer allowed in KYC rules.");

        // Deploy Price Oracle Reporter with initial price of 1 USD (assuming 6 decimals)
        uint256 initialPrice = 1_000_000; // $1.00 with 6 decimals
        PriceOracleReporter priceOracle = new PriceOracleReporter(initialPrice, deployer);

        console.log("Price Oracle Reporter deployed.");

        // Deploy ReportedStrategy implementation to be used as a template
        ReportedStrategy strategyImplementation = new ReportedStrategy();

        console.log("ReportedStrategy implementation deployed.");

        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImplementation), true);

        console.log("Registry configured.");

        // Encode initialization data for the strategy
        // For a reported strategy, the init data is the reporter address
        bytes memory initData = abi.encode(address(priceOracle));

        // Deploy a clone of ReportedStrategy through the registry
        (address strategy, address token) = registry.deploy(
            "Fountfi USD Token",      // name
            "fUSDC",                  // symbol
            address(strategyImplementation),
            address(usdToken),
            address(kycRules),
            deployer,
            deployer,
            initData
        );

        // Log deployed contract addresses
        console.log("\nDeployed contracts:");
        console.log("Mock USD Token:", address(usdToken));
        console.log("Registry:", address(registry));
        console.log("KYC Rules:", address(kycRules));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("Strategy Implementation:", address(strategyImplementation));
        console.log("Cloned Strategy:", strategy);
        console.log("Strategy Token:", token);

        vm.stopBroadcast();
    }
}