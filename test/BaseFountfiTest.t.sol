// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {Registry} from "../src/registry/Registry.sol";
import {RulesEngine} from "../src/rules/RulesEngine.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {SubscriptionRules} from "../src/rules/SubscriptionRules.sol";
import {CappedSubscriptionRules} from "../src/rules/CappedSubscriptionRules.sol";
import {BaseRules} from "../src/rules/BaseRules.sol";
import {IRules} from "../src/rules/IRules.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";

/**
 * @title BaseFountfiTest
 * @notice Base test contract with shared setup and utility functions
 */
abstract contract BaseFountfiTest is Test {
    // Test accounts
    address internal owner;
    address internal admin;
    address internal manager;
    address internal alice;
    address internal bob;
    address internal charlie;

    // Common contracts
    MockERC20 internal usdc;
    MockRules internal mockRules;
    MockReporter internal mockReporter;
    MockStrategy internal mockStrategy;
    Registry internal registry;

    // Base setup
    function setUp() public virtual {
        // Create test accounts
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Setup initial balances
        vm.deal(owner, 100 ether);
        vm.deal(admin, 100 ether);
        vm.deal(manager, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        // Deploy mock contracts
        vm.startPrank(owner);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Mint tokens to test accounts (10,000 USDC each)
        usdc.mint(alice, 10_000 * 10**6);
        usdc.mint(bob, 10_000 * 10**6);
        usdc.mint(charlie, 10_000 * 10**6);

        // Deploy mocks
        mockRules = new MockRules(true, "Mock rejection");
        mockReporter = new MockReporter(1000 * 10**6); // 1000 USDC initial value
        mockStrategy = new MockStrategy();

        // Deploy Registry
        registry = new Registry();
        vm.stopPrank();
    }

    // Helper to deploy a complete tRWA setup with mocks
    function deployMockTRWA(
        string memory name,
        string memory symbol
    ) internal returns (MockStrategy, tRWA) {
        // Init strategy and get token
        vm.startPrank(owner);
        
        // Create a fresh MockRules and ensure it's initialized to allow by default
        MockRules mockRulesLocal = new MockRules(true, "Test rejection");
        
        // Deploy a new strategy
        MockStrategy strategy = new MockStrategy();
        strategy.initialize(
            name,
            symbol,
            admin,
            manager,
            address(usdc),
            address(mockRulesLocal),
            ""
        );
        
        // Get the token the strategy created
        tRWA token = tRWA(strategy.sToken());
        vm.stopPrank();

        return (strategy, token);
    }

    // Helper to set allowances and deposit USDC to a tRWA token
    function depositTRWA(address user, address trwaToken, uint256 assets) internal returns (uint256) {
        vm.startPrank(user);
        usdc.approve(trwaToken, assets);
        uint256 shares = tRWA(trwaToken).deposit(assets, user);
        vm.stopPrank();
        return shares;
    }

    // Helper to create a complete test deployment via Registry
    function deployThroughRegistry() internal returns (
        address strategyAddr,
        address tokenAddr,
        KycRules kycRules,
        MockReporter reporter
    ) {
        vm.startPrank(owner);

        // Setup Registry
        registry.setAsset(address(usdc), true);

        // Deploy rules
        kycRules = new KycRules(owner); // Default is deny
        registry.setRules(address(kycRules), true);

        // Create reporter
        reporter = new MockReporter(1000 * 10**6);

        // Setup an implementation of MockStrategy
        MockStrategy strategyImpl = new MockStrategy();
        registry.setStrategy(address(strategyImpl), true);

        // Deploy via registry
        (strategyAddr, tokenAddr) = registry.deploy(
            "Test RWA",
            "TRWA",
            address(strategyImpl),
            address(usdc),
            address(kycRules),
            admin,
            manager,
            ""
        );

        vm.stopPrank();
    }
}