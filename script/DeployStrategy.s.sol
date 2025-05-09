// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {GatedMintReportedStrategy} from "../src/strategy/GatedMintRWAStrategy.sol";

contract DeployStrategyScript is Script {
    // Deployed contracts from previous scripts
    Registry public registry;
    MockERC20 public usdToken;
    PriceOracleReporter public priceOracle;
    address public strategyImplementation;
    
    // Deployment results
    address public strategy;
    address public token;

    function setUp() public {
        // Load deployed addresses from latest.json broadcast
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/broadcast/DeployProtocol.s.sol/run-latest.json");
        string memory json = vm.readFile(path);
        
        // Parse addresses from the JSON file
        address registryAddress = abi.decode(vm.parseJson(json, ".transactions[?(@.contractName=='Registry')].contractAddress"), (address));
        address usdTokenAddress = abi.decode(vm.parseJson(json, ".transactions[?(@.contractName=='MockERC20')].contractAddress"), (address));
        address priceOracleAddress = abi.decode(vm.parseJson(json, ".transactions[?(@.contractName=='PriceOracleReporter')].contractAddress"), (address));
        
        // Initialize contract references
        registry = Registry(registryAddress);
        usdToken = MockERC20(usdTokenAddress);
        priceOracle = PriceOracleReporter(priceOracleAddress);
        
        // Determine which strategy implementation to use based on environment variable
        string memory strategyType = vm.envOr("STRATEGY_TYPE", string("standard"));
        
        if (keccak256(abi.encodePacked(strategyType)) == keccak256(abi.encodePacked("gated"))) {
            // Use GatedMintReportedStrategy
            address gatedImpl = abi.decode(
                vm.parseJson(json, ".transactions[?(@.contractName=='GatedMintReportedStrategy')].contractAddress"), 
                (address)
            );
            strategyImplementation = gatedImpl;
            console.log("Using GatedMintReportedStrategy implementation");
        } else {
            // Default to standard ReportedStrategy
            address standardImpl = abi.decode(
                vm.parseJson(json, ".transactions[?(@.contractName=='ReportedStrategy')].contractAddress"), 
                (address)
            );
            strategyImplementation = standardImpl;
            console.log("Using ReportedStrategy implementation");
        }
    }

    function run() public {
        // Use the private key directly from the command line parameter
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy strategy
        deployStrategy(deployer);

        // Log deployed strategy
        logDeployedStrategy();

        vm.stopBroadcast();
    }

    function deployStrategy(address deployer) internal {
        // Encode initialization data for the strategy (reporter address)
        bytes memory initData = abi.encode(address(priceOracle));

        // Deploy strategy through registry
        (strategy, token) = registry.deploy(
            strategyImplementation,
            "Fountfi USD Token",      // name
            "fUSDC",                  // symbol
            address(usdToken),
            deployer,                 // Manager of the strategy
            initData
        );
        
        console.log("Strategy successfully deployed");
    }

    function logDeployedStrategy() internal view {
        // Log deployed strategy addresses
        console.log("\nDeployed Strategy:");
        console.log("Strategy Implementation:", strategyImplementation);
        console.log("Cloned Strategy:", strategy);
        console.log("Strategy Token:", token);
    }
}