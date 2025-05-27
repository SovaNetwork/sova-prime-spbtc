// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {MockHook} from "../src/mocks/MockHook.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {BaseReporter} from "../src/reporter/BaseReporter.sol";
import {Registry} from "../src/registry/Registry.sol";

/**
 * @title ReportedStrategyTest
 * @notice Tests for ReportedStrategy
 */
contract ReportedStrategyTest is BaseFountfiTest {
    // Test contracts
    ReportedStrategy public strategy;
    tRWA public token;
    RoleManager public roleManager;
    MockHook public strategyHook;
    MockERC20 public daiToken;
    MockReporter public reporter;

    // Strategy parameters
    string constant TOKEN_NAME = "Test Reporter Token";
    string constant TOKEN_SYMBOL = "TREP";
    uint256 constant INITIAL_PRICE_PER_SHARE = 1e18; // 1 token per share (18 decimals)

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy RoleManager first
        roleManager = new RoleManager();
        
        // Deploy Registry with RoleManager address
        registry = new Registry(address(roleManager));
        
        // Initialize the registry for RoleManager.
        roleManager.initializeRegistry(address(registry));

        // Deploy test DAI token as the asset
        daiToken = new MockERC20("DAI Stablecoin", "DAI", 18);
        
        // Register the DAI token as allowed asset in the registry
        registry.setAsset(address(daiToken), 18);

        // Deploy hook
        strategyHook = new MockHook(true, "");

        // Deploy reporter with initial price per share
        reporter = new MockReporter(INITIAL_PRICE_PER_SHARE);

        // Deploy the strategy implementation
        ReportedStrategy strategyImpl = new ReportedStrategy();
        
        // Register the strategy implementation in the registry
        registry.setStrategy(address(strategyImpl), true);

        // Deploy strategy and token through the registry
        bytes memory initData = abi.encode(address(reporter));
        (address strategyAddr, address tokenAddr) = registry.deploy(
            address(strategyImpl),
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(daiToken),
            manager,
            initData
        );
        
        strategy = ReportedStrategy(strategyAddr);
        token = tRWA(tokenAddr);

        vm.stopPrank();
        vm.startPrank(owner);
        // Fund the strategy with some DAI
        daiToken.mint(address(strategy), 1000 * 10**18);

        vm.stopPrank();
    }

    function test_Initialization() public view {
        // Check that the strategy was initialized correctly
        assertEq(strategy.registry(), address(registry), "Registry should be set correctly");
        assertEq(strategy.manager(), manager, "Manager should be set correctly");
        assertEq(strategy.asset(), address(daiToken), "Asset should be set correctly");
        assertEq(address(token), strategy.sToken(), "Token should be set correctly");

        // Check reporter setup
        assertEq(address(strategy.reporter()), address(reporter), "Reporter should be set correctly");

        // Check that the token was initialized correctly
        assertEq(token.name(), TOKEN_NAME, "Token name should be set correctly");
        assertEq(token.symbol(), TOKEN_SYMBOL, "Token symbol should be set correctly");
        assertEq(address(token.asset()), address(daiToken), "Token asset should be set correctly");
        assertEq(address(token.strategy()), address(strategy), "Token strategy should be set correctly");
    }

    function test_InitWithInvalidReporter() public {
        vm.startPrank(owner);

        // Deploy a new strategy to test initialization with invalid reporter
        ReportedStrategy newStrategy = new ReportedStrategy();

        // Create init data with address(0) reporter
        bytes memory invalidInitData = abi.encode(address(0));

        // Test zero address for reporter
        vm.expectRevert(ReportedStrategy.InvalidReporter.selector);
        newStrategy.initialize(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(roleManager),
            manager,
            address(daiToken),
            18,
            invalidInitData
        );

        vm.stopPrank();
    }

    function test_Balance() public {
        // Check the balance calculation with initial setup (should be 0 since no tokens minted yet)
        uint256 bal = strategy.balance();
        assertEq(bal, 0, "Balance should be 0 when no tokens are minted");

        // Mint some tokens to create total supply by depositing assets
        vm.prank(owner);
        daiToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice); // This will mint tokens
        vm.stopPrank();


        // Now balance should be pricePerShare * totalSupply = 1e18 * 1000e18 / 1e18 = 1000e18
        bal = strategy.balance();
        assertEq(bal, 1000e18, "Balance should be price per share * total supply");

        // Update the reporter's price per share
        reporter.setValue(2e18); // 2 tokens per share

        // Check the updated balance: 2e18 * 1000e18 / 1e18 = 2000e18
        bal = strategy.balance();
        assertEq(bal, 2000e18, "Balance should reflect new price per share");
    }

    function test_SetReporter() public {
        vm.startPrank(manager);

        // Deploy a new reporter with a different price per share
        MockReporter newReporter = new MockReporter(5e18); // 5 tokens per share

        // Update the reporter
        strategy.setReporter(address(newReporter));

        // Check that the reporter was updated
        assertEq(address(strategy.reporter()), address(newReporter), "Reporter should be updated");

        // Mint some tokens to test the calculation by depositing
        vm.stopPrank();
        vm.prank(owner);
        daiToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice);
        vm.stopPrank();
        vm.startPrank(manager);
        

        // Check that the balance reflects the new reporter's price per share
        // 5e18 * 1000e18 / 1e18 = 5000e18
        uint256 bal = strategy.balance();
        assertEq(bal, 5000e18, "Balance should match the new reporter's price per share calculation");

        vm.stopPrank();
    }

    function test_SetReporterInvalidAddress() public {
        vm.startPrank(manager);

        // Try to set reporter to address(0)
        vm.expectRevert(ReportedStrategy.InvalidReporter.selector);
        strategy.setReporter(address(0));

        vm.stopPrank();
    }

    function test_SetReporterUnauthorized() public {
        vm.startPrank(alice);

        // Alice is not the manager
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.setReporter(address(0));

        vm.stopPrank();
    }

    function test_PricePerShare() public {
        // Test getting price per share
        uint256 pricePerShare = strategy.pricePerShare();
        assertEq(pricePerShare, INITIAL_PRICE_PER_SHARE, "Price per share should match initial value");

        // Update reporter and check again
        reporter.setValue(2e18);
        pricePerShare = strategy.pricePerShare();
        assertEq(pricePerShare, 2e18, "Price per share should reflect updated value");
    }

    function test_CalculateTotalAssets() public {
        // With no tokens minted, total assets should be 0
        uint256 totalAssets = strategy.balance();
        assertEq(totalAssets, 0, "Total assets should be 0 with no tokens");

        // Mint some tokens by depositing
        vm.prank(owner);
        daiToken.mint(alice, 500e18);
        vm.startPrank(alice);
        // Alice needs to approve the Conduit, not the tRWA token
        daiToken.approve(registry.conduit(), 500e18);
        token.deposit(500e18, alice);
        vm.stopPrank();


        // Calculate expected total assets: 1e18 * 500e18 / 1e18 = 500e18
        totalAssets = strategy.balance();
        assertEq(totalAssets, 500e18, "Total assets should equal price per share * total supply");

        // Update price per share and check again
        reporter.setValue(3e18);
        totalAssets = strategy.balance();
        assertEq(totalAssets, 1500e18, "Total assets should reflect new price per share");
    }



    function test_DepositWithdrawFlow() public {
        // Setup: Give Alice some DAI to deposit
        vm.prank(owner);
        daiToken.mint(alice, 2000e18);

        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 2000e18);

        // Initial state: no tokens minted, price per share = 1e18
        assertEq(token.totalSupply(), 0, "Initial total supply should be 0");
        assertEq(token.totalAssets(), 0, "Initial total assets should be 0");

        // Alice deposits 1000 DAI
        uint256 shares1 = token.deposit(1000e18, alice);

        // With price per share = 1e18, she should get 1000 shares
        assertEq(shares1, 1000e18, "Should get 1000 shares for 1000 DAI at 1:1 ratio");
        assertEq(token.totalSupply(), 1000e18, "Total supply should be 1000");
        
        
        assertEq(token.totalAssets(), 1000e18, "Total assets should be 1000 (1e18 * 1000e18 / 1e18)");

        // Update price per share to 1.5 (fund performance)
        vm.stopPrank();
        reporter.setValue(1.5e18);

        // Total assets should now reflect the new price
        assertEq(token.totalAssets(), 1500e18, "Total assets should be 1500 (1.5e18 * 1000e18 / 1e18)");

        // Alice deposits another 1000 DAI at the new price
        vm.startPrank(alice);
        uint256 shares2 = token.deposit(1000e18, alice);

        // At price 1.5, she should get 1000/1.5 = 666.67 shares (approximately)
        // The exact calculation depends on ERC4626 share pricing
        assertTrue(shares2 < 1000e18, "Should get fewer shares at higher price");
        assertTrue(shares2 > 600e18, "Should get more than 600 shares");

        uint256 totalSupplyAfter = token.totalSupply();
        
        
        uint256 totalAssetsAfter = token.totalAssets();
        
        // Total assets should be approximately 2500 (1.5 * new total supply)
        uint256 expectedAssets = (1.5e18 * totalSupplyAfter) / 1e18;
        assertApproxEqRel(totalAssetsAfter, expectedAssets, 0.01e18, "Total assets should match price per share calculation");

        vm.stopPrank();
    }

    function test_ImmediateReflectionOfDeposits() public {
        // This test verifies that deposits are immediately reflected in totalAssets
        // even without oracle updates, which was the main problem we're solving

        vm.prank(owner);
        daiToken.mint(alice, 1500e18); // Need enough for both deposits

        vm.startPrank(alice);
        daiToken.approve(registry.conduit(), 1500e18); // Approve enough for both deposits

        // Before deposit
        uint256 assetsBefore = token.totalAssets();
        assertEq(assetsBefore, 0, "Assets should be 0 before deposit");

        // Deposit
        token.deposit(1000e18, alice);

        // After deposit - should immediately reflect the new assets
        // pricePerShare (1e18) * totalSupply (1000e18) = 1000e18
        uint256 assetsAfter = token.totalAssets();
        assertEq(assetsAfter, 1000e18, "Assets should immediately reflect deposit");

        // The key test: deposit again without oracle update
        token.deposit(500e18, alice);

        // Should immediately reflect the additional deposit
        // The second deposit gets 500 more shares (1:1 since totalAssets = totalSupply)
        // pricePerShare (1e18) * totalSupply (1500e18) = 1500e18
        uint256 assetsFinal = token.totalAssets();
        assertEq(assetsFinal, 1500e18, "Assets should immediately reflect second deposit");

        vm.stopPrank();
    }
}