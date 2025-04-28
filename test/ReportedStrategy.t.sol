// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {BasicStrategy} from "../src/strategy/BasicStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {BaseReporter} from "../src/reporter/BaseReporter.sol";

/**
 * @title ReportedStrategyTest
 * @notice Tests for ReportedStrategy
 */
contract ReportedStrategyTest is BaseFountfiTest {
    // Test contracts
    ReportedStrategy public strategy;
    tRWA public token;
    MockRoleManager public roleManager;
    MockRules public strategyRules;
    MockERC20 public daiToken;
    MockReporter public reporter;

    // Strategy parameters
    string constant TOKEN_NAME = "Test Reporter Token";
    string constant TOKEN_SYMBOL = "TREP";
    uint256 constant INITIAL_NAV = 1000 * 10**18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy a new role manager for the strategy
        roleManager = new MockRoleManager(owner);
        
        // Grant strategy admin role to owner
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        
        // Deploy test DAI token as the asset
        daiToken = new MockERC20("DAI Stablecoin", "DAI", 18);
        
        // Deploy rules
        strategyRules = new MockRules(true, "");
        
        // Deploy reporter with initial NAV value
        reporter = new MockReporter(INITIAL_NAV);
        
        // Deploy the strategy
        strategy = new ReportedStrategy(address(roleManager));
        
        // Initialize the strategy
        bytes memory initData = abi.encode(address(reporter));
        strategy.initialize(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            manager,
            address(daiToken),
            address(strategyRules),
            initData
        );
        
        // Get the token that was deployed during initialization
        token = tRWA(strategy.sToken());
        
        // Fund the strategy with some DAI
        daiToken.mint(address(strategy), 1000 * 10**18);
        
        vm.stopPrank();
    }
    
    function test_Initialization() public {
        // Check that the strategy was initialized correctly
        assertEq(strategy.deployer(), owner, "Deployer should be set to owner");
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
        ReportedStrategy newStrategy = new ReportedStrategy(address(roleManager));
        
        // Create init data with address(0) reporter
        bytes memory invalidInitData = abi.encode(address(0));
        
        // Test zero address for reporter
        vm.expectRevert(ReportedStrategy.InvalidReporter.selector);
        newStrategy.initialize(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            manager,
            address(daiToken),
            address(strategyRules),
            invalidInitData
        );
        
        vm.stopPrank();
    }
    
    function test_Balance() public {
        // Check the balance equals what the reporter returns
        uint256 bal = strategy.balance();
        assertEq(bal, INITIAL_NAV, "Balance should match reporter's value");
        
        // Update the reporter's value
        reporter.setValue(2000 * 10**18);
        
        // Check the updated balance
        bal = strategy.balance();
        assertEq(bal, 2000 * 10**18, "Balance should match the updated reporter value");
    }
    
    function test_SetReporter() public {
        vm.startPrank(manager);
        
        // Deploy a new reporter with a different value
        MockReporter newReporter = new MockReporter(5000 * 10**18);
        
        // Update the reporter
        strategy.setReporter(address(newReporter));
        
        // Check that the reporter was updated
        assertEq(address(strategy.reporter()), address(newReporter), "Reporter should be updated");
        
        // Check that the balance reflects the new reporter's value
        uint256 bal = strategy.balance();
        assertEq(bal, 5000 * 10**18, "Balance should match the new reporter's value");
        
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
    
    function test_TransferAssets() public {
        vm.startPrank(manager);
        
        uint256 initialBob = daiToken.balanceOf(bob);
        uint256 initialStrategy = daiToken.balanceOf(address(strategy));
        
        // Transfer 100 DAI to bob
        strategy.transferAssets(bob, 100 * 10**18);
        
        assertEq(daiToken.balanceOf(bob), initialBob + 100 * 10**18, "Bob should receive 100 DAI");
        assertEq(daiToken.balanceOf(address(strategy)), initialStrategy - 100 * 10**18, "Strategy should send 100 DAI");
        
        vm.stopPrank();
    }
    
    function test_TransferAssetsUnauthorized() public {
        vm.startPrank(alice);
        
        // Alice is not the manager
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.transferAssets(bob, 100 * 10**18);
        
        vm.stopPrank();
    }
    
    function test_InheritedFeatures() public {
        // Test some inherited features from BasicStrategy
        
        vm.startPrank(manager);
        
        // Configure the controller
        strategy.configureController(alice);
        assertEq(strategy.controller(), alice, "Controller should be set to alice");
        
        // Try to configure it again (should fail)
        vm.expectRevert(IStrategy.AlreadyInitialized.selector);
        strategy.configureController(bob);
        
        vm.stopPrank();
        
        // Test other access controls
        vm.startPrank(alice);
        
        // Alice is not the manager
        vm.expectRevert(IStrategy.Unauthorized.selector);
        strategy.sendETH(bob);
        
        vm.stopPrank();
    }
}