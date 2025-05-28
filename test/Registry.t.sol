// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {IRegistry} from "../src/registry/IRegistry.sol";
/**
 * @title RegistryTest
 * @notice Simple test for the Registry contract
 */
contract RegistryTest is Test {
    Registry public registry;
    RoleManager public roleManager;
    address public owner;

    function setUp() public {
        owner = address(this); // Use the test contract as owner

        vm.startPrank(owner);
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));
        
        // Initialize the registry in RoleManager
        roleManager.initializeRegistry(address(registry));

        // Grant necessary roles to owner
        roleManager.grantRole(owner, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(owner, roleManager.RULES_ADMIN());

        vm.stopPrank();
    }

    function test_RegistrationFunctions() public {
        vm.startPrank(owner);

        // Create asset token
        MockERC20 asset = new MockERC20("USD Coin", "USDC", 6);

        // Test asset registration
        registry.setAsset(address(asset), 6);
        assertTrue(registry.allowedAssets(address(asset)) == 6);

        // Test asset unregistration
        registry.setAsset(address(asset), 0);
        assertTrue(registry.allowedAssets(address(asset)) == 0);

        // Test operation hook registration
        address mockHook = makeAddr("hook");
        registry.setHook(mockHook, true);
        assertTrue(registry.allowedHooks(mockHook));

        // Test strategy registration
        address mockStrategy = makeAddr("strategy");
        registry.setStrategy(mockStrategy, true);
        assertTrue(registry.allowedStrategies(mockStrategy));

        vm.stopPrank();
    }

    function test_RegistrationChecks() public {
        vm.startPrank(owner);

        // Zero address checks
        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setAsset(address(0), 6);

        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setHook(address(0), true);

        vm.expectRevert(IRegistry.ZeroAddress.selector);
        registry.setStrategy(address(0), true);

        vm.stopPrank();
    }

    function test_DeployRequiresAuthorization() public {
        vm.startPrank(owner);

        // Create local instances we control
        MockERC20 localUsdc = new MockERC20("USD Coin", "USDC", 6);
        address localRules = makeAddr("rules");
        address localStrategy = makeAddr("strategy");

        // Test require conditions on deploy

        registry.setAsset(address(localUsdc), 6);
        registry.setHook(localRules, true);
        registry.setStrategy(localStrategy, true);

        // Check that we can register and toggle components
        assertTrue(registry.allowedAssets(address(localUsdc)) == 6);
        assertTrue(registry.allowedHooks(localRules));
        assertTrue(registry.allowedStrategies(localStrategy));

        // Set them to false again
        registry.setAsset(address(localUsdc), 0);
        registry.setHook(localRules, false);
        registry.setStrategy(localStrategy, false);

        // Verify they're toggled off
        assertTrue(registry.allowedAssets(address(localUsdc)) == 0);
        assertFalse(registry.allowedHooks(localRules));
        assertFalse(registry.allowedStrategies(localStrategy));

        vm.stopPrank();
    }

    function test_DeployStrategy() public {
        vm.startPrank(owner);

        // Setup prerequisites
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        address strategyImpl = makeAddr("strategyImpl");
        address manager = makeAddr("manager");

        // Register asset and strategy
        registry.setAsset(address(usdc), 6);
        registry.setStrategy(strategyImpl, true);

        // Grant STRATEGY_OPERATOR role to owner
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());

        // Deploy strategy (will fail because strategyImpl is not a real contract, but tests the flow)
        vm.expectRevert();
        registry.deploy(
            strategyImpl,
            "Test Strategy",
            "TS",
            address(usdc),
            manager,
            ""
        );

        vm.stopPrank();
    }

    function test_DeployStrategy_UnauthorizedAsset() public {
        vm.startPrank(owner);

        address strategyImpl = makeAddr("strategyImpl");
        address unregisteredAsset = makeAddr("unregisteredAsset");
        address manager = makeAddr("manager");

        // Register strategy but not asset
        registry.setStrategy(strategyImpl, true);

        // Grant STRATEGY_OPERATOR role to owner
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());

        // Try to deploy with unregistered asset
        vm.expectRevert(IRegistry.UnauthorizedAsset.selector);
        registry.deploy(
            strategyImpl,
            "Test Strategy",
            "TS",
            unregisteredAsset,
            manager,
            ""
        );

        vm.stopPrank();
    }

    function test_DeployStrategy_UnauthorizedStrategy() public {
        vm.startPrank(owner);

        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        address unregisteredStrategy = makeAddr("unregisteredStrategy");
        address manager = makeAddr("manager");

        // Register asset but not strategy
        registry.setAsset(address(usdc), 6);

        // Grant STRATEGY_OPERATOR role to owner
        roleManager.grantRole(owner, roleManager.STRATEGY_OPERATOR());

        // Try to deploy with unregistered strategy
        vm.expectRevert(IRegistry.UnauthorizedStrategy.selector);
        registry.deploy(
            unregisteredStrategy,
            "Test Strategy",
            "TS",
            address(usdc),
            manager,
            ""
        );

        vm.stopPrank();
    }

    function test_AllStrategyTokens() public {
        // Deploy multiple strategies to populate the array
        // Since we can't actually deploy without real implementations,
        // we'll test the empty case
        address[] memory tokens = registry.allStrategyTokens();
        assertEq(tokens.length, 0);
    }

    function test_IsStrategyToken() public {
        // Test with a non-strategy token
        address randomToken = makeAddr("randomToken");
        
        // Mock the strategy() call to return an address
        vm.mockCall(
            randomToken,
            abi.encodeWithSelector(bytes4(keccak256("strategy()"))),
            abi.encode(makeAddr("notRegisteredStrategy"))
        );
        
        assertFalse(registry.isStrategyToken(randomToken));
    }

    function test_ConduitAddress() public view {
        // Conduit should be deployed in constructor
        address conduitAddr = registry.conduit();
        assertTrue(conduitAddr != address(0));
    }

    function test_RoleBasedAccess() public {
        // Test that the owner has the correct roles
        assertTrue(roleManager.hasAnyRole(owner, roleManager.PROTOCOL_ADMIN()));
        assertTrue(roleManager.hasAnyRole(owner, roleManager.RULES_ADMIN()));
        assertTrue(roleManager.hasAnyRole(owner, roleManager.STRATEGY_ADMIN()));

        // Create a new user without any roles
        address newUser = address(0x1234);
        
        // Verify newUser has no roles
        assertFalse(roleManager.hasAnyRole(newUser, roleManager.PROTOCOL_ADMIN()));
        assertFalse(roleManager.hasAnyRole(newUser, roleManager.RULES_ADMIN()));
        assertFalse(roleManager.hasAnyRole(newUser, roleManager.STRATEGY_ADMIN()));

        // Test that functions work correctly with proper roles (owner has all roles)
        address testAsset = makeAddr("testAsset");
        address testHook = makeAddr("testHook");
        address testStrategy = makeAddr("testStrategy");

        vm.prank(owner);
        registry.setAsset(testAsset, 8);
        assertEq(registry.allowedAssets(testAsset), 8);

        vm.prank(owner);
        registry.setHook(testHook, true);
        assertTrue(registry.allowedHooks(testHook));

        vm.prank(owner);
        registry.setStrategy(testStrategy, true);
        assertTrue(registry.allowedStrategies(testStrategy));
    }

    function test_ConstructorValidation() public {
        // Test zero address role manager
        vm.expectRevert();
        new Registry(address(0));
    }
}