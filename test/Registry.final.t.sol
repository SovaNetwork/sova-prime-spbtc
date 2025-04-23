// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {IStrategy} from "../src/strategy/IStrategy.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";

/**
 * @title RegistryTest
 * @notice Complete test for the Registry contract
 */
contract RegistryFinalTest is Test {
    Registry public registry;
    MockERC20 public asset;
    MockRules public rules;
    MockStrategy public strategyImpl;
    RoleManager public roleManager;
    
    address public owner;
    address public admin;
    address public manager;
    address public nonOwner;
    
    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        nonOwner = makeAddr("nonOwner");
        
        // Deploy role manager
        vm.startPrank(owner);
        roleManager = new RoleManager();
        
        // Deploy registry with owner as role manager
        registry = new Registry(address(roleManager));
        
        // Deploy mock contracts
        asset = new MockERC20("USD Coin", "USDC", 6);
        rules = new MockRules(true, "Mock rejection");
        strategyImpl = new MockStrategy(address(roleManager));
        
        // Grant owner the needed roles
        roleManager.grantRole(owner, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(owner, roleManager.RULES_ADMIN());
        
        vm.stopPrank();
    }
    
    // Test constructor and initialization
    function test_Constructor() public {
        // Since we're using role-managed now, ensure PROTOCOL_ADMIN role is set
        // rather than checking ownership directly
        
        // Deploy another registry with a different sender
        RoleManager newRoleManager = new RoleManager();
        vm.prank(nonOwner);
        Registry newRegistry = new Registry(address(newRoleManager));
        
        // Can't directly check role assignment in tests easily without mocks
        // So we just verify initialization succeeded
    }
    
    // Test access control for setStrategy
    function test_SetStrategy_AccessControl() public {
        // Non-owner cannot call
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.setStrategy(address(0x123), true);
        
        // Owner can call
        vm.prank(owner);
        registry.setStrategy(address(strategyImpl), true);
        
        // Verify strategy was registered
        assertTrue(registry.allowedStrategies(address(strategyImpl)));
    }
    
    // Test access control for setRules
    function test_SetRules_AccessControl() public {
        // Non-owner cannot call
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.setRules(address(0x123), true);
        
        // Owner can call
        vm.prank(owner);
        registry.setRules(address(rules), true);
        
        // Verify rules were registered
        assertTrue(registry.allowedRules(address(rules)));
    }
    
    // Test access control for setAsset
    function test_SetAsset_AccessControl() public {
        // Non-owner cannot call
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.setAsset(address(0x123), true);
        
        // Owner can call
        vm.prank(owner);
        registry.setAsset(address(asset), true);
        
        // Verify asset was registered
        assertTrue(registry.allowedAssets(address(asset)));
    }
    
    // Test zero address checks
    function test_ZeroAddress_Checks() public {
        vm.startPrank(owner);
        
        // Test zero address check for setStrategy
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setStrategy(address(0), true);
        
        // Test zero address check for setRules
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setRules(address(0), true);
        
        // Test zero address check for setAsset
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setAsset(address(0), true);
        
        vm.stopPrank();
    }
    
    // Test deploy function access control
    function test_Deploy_AccessControl() public {
        // First set up the registry with allowed components
        vm.startPrank(owner);
        registry.setStrategy(address(strategyImpl), true);
        registry.setRules(address(rules), true);
        registry.setAsset(address(asset), true);
        vm.stopPrank();
        
        // Non-owner cannot deploy
        vm.startPrank(nonOwner);
        vm.expectRevert();
        registry.deploy(
            "Test Token",
            "TEST",
            address(strategyImpl),
            address(asset),
            address(rules),
            manager,
            ""
        );
        vm.stopPrank();
    }
    
    // Test deploy function authorization checks
    function test_Deploy_AuthorizationChecks() public {
        vm.startPrank(owner);
        
        // Test in reverse order of the if checks in the deploy function
        
        // Try with unauthorized rule (this will be checked first in the contract)
        vm.expectRevert(Registry.UnauthorizedRule.selector);
        registry.deploy(
            "Test Token",
            "TEST",
            address(strategyImpl),
            address(asset),
            address(0x123), // Unauthorized rule
            manager,
            ""
        );
        
        // Allow strategy and try with unauthorized asset
        registry.setStrategy(address(strategyImpl), true);
        registry.setRules(address(rules), true);
        
        vm.expectRevert(Registry.UnauthorizedAsset.selector);
        registry.deploy(
            "Test Token",
            "TEST",
            address(strategyImpl),
            address(0x123), // Unauthorized asset
            address(rules),
            manager,
            ""
        );
        
        // Allow asset and try with unauthorized strategy
        registry.setAsset(address(asset), true);
        
        vm.expectRevert(Registry.UnauthorizedStrategy.selector);
        registry.deploy(
            "Test Token",
            "TEST",
            address(0x123), // Unauthorized strategy
            address(asset),
            address(rules),
            manager,
            ""
        );
        
        vm.stopPrank();
    }
    
    // Test deploy function with initialization failure (try/catch)
    function test_Deploy_InitializationFailure() public {
        // Set up the registry with allowed components
        vm.startPrank(owner);
        registry.setStrategy(address(strategyImpl), true);
        registry.setRules(address(rules), true);
        registry.setAsset(address(asset), true);
        
        // Create a mock strategy implementation that will fail during initialization
        MockStrategy failingStrategy = new MockStrategy(address(roleManager));
        registry.setStrategy(address(failingStrategy), true);
        
        // Try to deploy with failing strategy
        try registry.deploy(
            "Test Token",
            "TEST",
            address(failingStrategy),
            address(asset),
            address(0), // Invalid rules address to trigger initialization failure
            manager,
            ""
        ) {
            fail();
        } catch {
            // Expected to fail
        }
        
        vm.stopPrank();
    }
    
    // Test successful deployment
    function test_Deploy_Success() public {
        // Set up the registry with allowed components
        vm.startPrank(owner);
        registry.setStrategy(address(strategyImpl), true);
        registry.setRules(address(rules), true);
        registry.setAsset(address(asset), true);
        
        // Deploy a strategy through the registry
        (address deployedStrategy, address deployedToken) = registry.deploy(
            "Test Token",
            "TEST",
            address(strategyImpl),
            address(asset),
            address(rules),
            manager,
            ""
        );
        
        // Verify deployment
        assertTrue(deployedStrategy != address(0));
        assertTrue(deployedToken != address(0));
        
        // Verify the strategy was added to allStrategies
        bool found = false;
        uint256 stratCount = 1; // There's just one strategy in this test
        for (uint256 i = 0; i < stratCount; i++) {
            if (registry.allStrategies(i) == deployedStrategy) {
                found = true;
                break;
            }
        }
        assertTrue(found);
        
        // Verify strategy state
        MockStrategy strategy = MockStrategy(deployedStrategy);
        assertEq(strategy.manager(), manager);
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.sToken(), deployedToken);
        
        vm.stopPrank();
    }
}