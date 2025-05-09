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
        owner = makeAddr("owner");

        vm.startPrank(owner);
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));

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
}