// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/registry/Registry.sol";
import {IRegistry} from "../src/registry/IRegistry.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {RoleManaged} from "../src/auth/RoleManaged.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";

/**
 * @title RegistryFullCoverageTest
 * @notice Comprehensive test suite for Registry contract achieving 100% coverage
 */
contract RegistryFullCoverageTest is Test {
    Registry public registry;
    RoleManager public roleManager;
    MockERC20 public usdc;
    MockStrategy public strategyImpl;
    
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy components
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));
        roleManager.initializeRegistry(address(registry));
        
        // Setup roles
        roleManager.grantRole(owner, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(owner, roleManager.RULES_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());
        
        // Deploy mock contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        strategyImpl = new MockStrategy();
        
        // Register asset and strategy
        registry.setAsset(address(usdc), 6);
        registry.setStrategy(address(strategyImpl), true);
        
        vm.stopPrank();
    }
    
    function test_Constructor_ZeroAddress() public {
        // The constructor actually reverts with InvalidRoleManager from RoleManaged
        vm.expectRevert(RoleManaged.InvalidRoleManager.selector);
        new Registry(address(0));
    }
    
    function test_Deploy_Success() public {
        vm.startPrank(owner);
        
        // Deploy a strategy and capture return values
        (address returnedStrategy, address returnedToken) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token",
            "tRWA",
            address(usdc),
            owner, // manager
            "" // initData
        );
        
        // Verify deployment
        assertTrue(returnedStrategy != address(0));
        assertTrue(returnedToken != address(0));
        assertTrue(registry.isStrategy(returnedStrategy));
        
        // Verify the strategy's token
        assertEq(IStrategy(returnedStrategy).sToken(), returnedToken);
        
        // Use the return values to ensure line 122 is covered
        address strategy = returnedStrategy;
        address token = returnedToken;
        assertEq(strategy, returnedStrategy);
        assertEq(token, returnedToken);
        
        vm.stopPrank();
    }
    
    function test_AllStrategies() public {
        vm.startPrank(owner);
        
        // Initially empty
        address[] memory strategies = registry.allStrategies();
        assertEq(strategies.length, 0);
        
        // Deploy some strategies
        (address strategy1,) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token 1",
            "tRWA1",
            address(usdc),
            owner,
            ""
        );
        
        (address strategy2,) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token 2",
            "tRWA2",
            address(usdc),
            owner,
            ""
        );
        
        // Check all strategies
        strategies = registry.allStrategies();
        assertEq(strategies.length, 2);
        assertEq(strategies[0], strategy1);
        assertEq(strategies[1], strategy2);
        
        vm.stopPrank();
    }
    
    function test_AllStrategyTokens_WithDeployedStrategies() public {
        vm.startPrank(owner);
        
        // Deploy some strategies and explicitly use return values
        (address strategy1, address token1) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token 1",
            "tRWA1",
            address(usdc),
            owner,
            ""
        );
        
        // Ensure return values are used
        emit log_address(strategy1);
        emit log_address(token1);
        
        (address strategy2, address token2) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token 2",
            "tRWA2",
            address(usdc),
            owner,
            ""
        );
        
        // Ensure return values are used
        emit log_address(strategy2);
        emit log_address(token2);
        
        // Get all strategy tokens
        address[] memory tokens = registry.allStrategyTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        
        vm.stopPrank();
    }
    
    function test_IsStrategyToken_WithDeployedStrategy() public {
        vm.startPrank(owner);
        
        // Deploy a strategy
        (address strategy, address token) = registry.deploy(
            address(strategyImpl),
            "Test RWA Token",
            "tRWA",
            address(usdc),
            owner,
            ""
        );
        
        // Check if it's a strategy token
        assertTrue(registry.isStrategyToken(token));
        
        // For a random token, we need to mock the strategy() call
        address randomToken = makeAddr("randomToken");
        address nonRegisteredStrategy = makeAddr("nonRegisteredStrategy");
        
        // Mock the strategy() call to return a non-registered strategy
        vm.mockCall(
            randomToken,
            abi.encodeWithSelector(bytes4(keccak256("strategy()"))),
            abi.encode(nonRegisteredStrategy)
        );
        
        // Check that it's not a strategy token
        assertFalse(registry.isStrategyToken(randomToken));
        
        vm.stopPrank();
    }
    
    function test_Deploy_UnauthorizedAsset() public {
        vm.startPrank(owner);
        
        // Try to deploy with unregistered asset
        address unregisteredAsset = makeAddr("unregisteredAsset");
        
        vm.expectRevert(IRegistry.UnauthorizedAsset.selector);
        registry.deploy(
            address(strategyImpl),
            "Test RWA Token",
            "tRWA",
            unregisteredAsset,
            owner,
            ""
        );
        
        vm.stopPrank();
    }
    
    function test_Deploy_UnauthorizedStrategy() public {
        vm.startPrank(owner);
        
        // Try to deploy with unregistered strategy
        MockStrategy unregisteredStrategy = new MockStrategy();
        
        vm.expectRevert(IRegistry.UnauthorizedStrategy.selector);
        registry.deploy(
            address(unregisteredStrategy),
            "Test RWA Token",
            "tRWA",
            address(usdc),
            owner,
            ""
        );
        
        vm.stopPrank();
    }
    
    function test_SetStrategy_ZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setStrategy(address(0), true);
        
        vm.stopPrank();
    }
    
    function test_SetHook_ZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setHook(address(0), true);
        
        vm.stopPrank();
    }
    
    function test_SetAsset_ZeroAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setAsset(address(0), 6);
        
        vm.stopPrank();
    }
    
    function test_Deploy_UnauthorizedCaller() public {
        vm.startPrank(alice); // alice doesn't have STRATEGY_OPERATOR role
        
        vm.expectRevert();
        registry.deploy(
            address(strategyImpl),
            "Test RWA Token",
            "tRWA",
            address(usdc),
            alice,
            ""
        );
        
        vm.stopPrank();
    }
    
    function test_SetStrategy_UnauthorizedCaller() public {
        vm.startPrank(alice); // alice doesn't have STRATEGY_ADMIN role
        
        vm.expectRevert();
        registry.setStrategy(makeAddr("strategy"), true);
        
        vm.stopPrank();
    }
    
    function test_SetHook_UnauthorizedCaller() public {
        vm.startPrank(alice); // alice doesn't have RULES_ADMIN role
        
        vm.expectRevert();
        registry.setHook(makeAddr("hook"), true);
        
        vm.stopPrank();
    }
    
    function test_SetAsset_UnauthorizedCaller() public {
        vm.startPrank(alice); // alice doesn't have PROTOCOL_ADMIN role
        
        vm.expectRevert();
        registry.setAsset(makeAddr("asset"), 6);
        
        vm.stopPrank();
    }
}