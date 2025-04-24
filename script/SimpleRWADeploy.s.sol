// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {SubscriptionController} from "../src/controllers/SubscriptionController.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";

contract SimpleRWADeployScript is Script {
    // Management addresses
    address public constant MANAGER_1 = 0x0670faf0016E1bf591fEd8e0322689E894104F81;
    address public constant MANAGER_2 = 0xc67DD6f32147285A9e4D92774055cE3Dba5Ae8b6;

    // Storage for deployed contract addresses
    RoleManager public roleManager;
    MockERC20 public usdToken;
    Registry public registry;
    KycRules public kycRules;
    PriceOracleReporter public priceOracle;
    ReportedStrategy public strategyImplementation;
    address public strategy;
    address public token;
    address public controller;
    uint256 public startTime;
    uint256 public endTime;

    function setUp() public {}

    function run() public {
        // Use the private key directly from the command line parameter
        uint256 deployerPrivateKey = 0x267aedad5dceb451cc0a93b451dd21726b4a23bb83d946c9d0e0e2587069684a;
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core infrastructure
        deployInfrastructure(deployer);

        // Deploy strategy and controller
        deployStrategyAndController(deployer);

        // Configure controller and roles
        configureController();

        // Log all deployed contracts
        logDeployedContracts();

        vm.stopBroadcast();
    }

    function deployInfrastructure(address deployer) internal {
        // Deploy Role Manager first for better access control
        roleManager = new RoleManager();

        // Grant admin roles to manager addresses
        grantRolesToManagers();

        console.log("RoleManager deployed and roles configured.");

        // Deploy mock USD token
        usdToken = new MockERC20("Mock USD", "USDC", 6);

        // Mint tokens to various addresses for testing
        usdToken.mint(deployer, 1_000_000_000); // 1,000 USDC with 6 decimals
        usdToken.mint(MANAGER_1, 1_000_000_000); // 1,000 USDC with 6 decimals
        usdToken.mint(MANAGER_2, 1_000_000_000); // 1,000 USDC with 6 decimals

        console.log("Mock USD Token deployed and minted to managers.");

        // Deploy Registry with role manager
        registry = new Registry(address(roleManager));
        console.log("Registry deployed.");

        // Allow USD token as an asset
        registry.setAsset(address(usdToken), true);

        // Deploy KYC Rules with role manager
        kycRules = new KycRules(address(roleManager));
        console.log("KYC Rules deployed.");

        // Add this rule to allowed rules in registry
        registry.setRules(address(kycRules), true);

        // Allow addresses in KYC rules
        kycRules.allow(deployer);
        kycRules.allow(MANAGER_1);
        kycRules.allow(MANAGER_2);
        console.log("Managers allowed in KYC rules.");

        // Deploy Price Oracle Reporter with initial price of 1 USD
        uint256 initialPrice = 1_000_000; // $1.00 with 6 decimals
        priceOracle = new PriceOracleReporter(initialPrice, address(roleManager));
        console.log("Price Oracle Reporter deployed.");

        // Deploy ReportedStrategy implementation to be used as a template
        strategyImplementation = new ReportedStrategy(address(roleManager));
        console.log("ReportedStrategy implementation deployed.");

        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImplementation), true);
        console.log("Registry configured.");
    }

    function grantRolesToManagers() internal {
        // Protocol admins
        roleManager.grantRole(MANAGER_1, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.PROTOCOL_ADMIN());

        // Strategy roles
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.STRATEGY_MANAGER());
        roleManager.grantRole(MANAGER_2, roleManager.STRATEGY_MANAGER());

        // Rules admins
        roleManager.grantRole(MANAGER_1, roleManager.RULES_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.RULES_ADMIN());

        // KYC roles
        roleManager.grantRole(MANAGER_1, roleManager.KYC_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.KYC_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.KYC_OPERATOR());
        roleManager.grantRole(MANAGER_2, roleManager.KYC_OPERATOR());

        // Reporter roles
        roleManager.grantRole(MANAGER_1, roleManager.REPORTER_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.REPORTER_ADMIN());
        roleManager.grantRole(MANAGER_1, roleManager.DATA_PROVIDER());
        roleManager.grantRole(MANAGER_2, roleManager.DATA_PROVIDER());

        // Subscription admins
        roleManager.grantRole(MANAGER_1, roleManager.SUBSCRIPTION_ADMIN());
        roleManager.grantRole(MANAGER_2, roleManager.SUBSCRIPTION_ADMIN());
    }

    function deployStrategyAndController(address deployer) internal {
        // Encode initialization data for the strategy (reporter address)
        bytes memory initData = abi.encode(address(priceOracle));
        
        // Create array of additional manager addresses
        address[] memory managerAddresses = new address[](2);
        managerAddresses[0] = MANAGER_1;
        managerAddresses[1] = MANAGER_2;

        // Deploy a clone of ReportedStrategy with controller through the registry
        (strategy, token, controller) = registry.deployWithController(
            "Fountfi USD Token",      // name
            "fUSDC",                  // symbol
            address(strategyImplementation),
            address(usdToken),
            address(kycRules),
            deployer,                 // Manager of the strategy
            managerAddresses,         // Additional manager addresses for controller
            initData,
            10000                     // Initial capacity of 10,000 subscribers
        );

        // Configure subscription round - Start now, end in 90 days
        startTime = block.timestamp;
        endTime = startTime + 90 days;

        SubscriptionController(controller).openSubscriptionRound(
            "Genesis Offering Q2 2025",
            startTime,
            endTime,
            10000                    // cap of 10,000 subscribers
        );
    }

    function configureController() internal {
        // Set up the token with the controller reference
        BasicStrategy(strategy).configureController(controller);
        console.log("Controller configured for strategy");
    }

    function logDeployedContracts() internal view {
        // Log deployed contract addresses
        console.log("\nDeployed contracts:");
        console.log("Role Manager:", address(roleManager));
        console.log("Mock USD Token:", address(usdToken));
        console.log("Registry:", address(registry));
        console.log("KYC Rules:", address(kycRules));
        console.log("Price Oracle Reporter:", address(priceOracle));
        console.log("Strategy Implementation:", address(strategyImplementation));
        console.log("Cloned Strategy:", strategy);
        console.log("Strategy Token:", token);
        console.log("Subscription Controller:", controller);

        console.log("\nSubscription Round Details:");
        console.log("Start Time:", startTime);
        console.log("End Time:", endTime);
        console.log("Duration:", (endTime - startTime) / 1 days, "days");
        console.log("Capacity:", 10000, "subscribers");
    }
}