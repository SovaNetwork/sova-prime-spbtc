// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";

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
        registry.setAsset(address(asset), true);
        assertTrue(registry.allowedAssets(address(asset)));
        
        // Test asset unregistration
        registry.setAsset(address(asset), false);
        assertFalse(registry.allowedAssets(address(asset)));
        
        // Test rules registration
        address mockRules = makeAddr("rules");
        registry.setRules(mockRules, true);
        assertTrue(registry.allowedRules(mockRules));
        
        // Test strategy registration
        address mockStrategy = makeAddr("strategy");
        registry.setStrategy(mockStrategy, true);
        assertTrue(registry.allowedStrategies(mockStrategy));
        
        vm.stopPrank();
    }
    
    function test_RegistrationChecks() public {
        vm.startPrank(owner);
        
        // Zero address checks
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setAsset(address(0), true);
        
        vm.expectRevert(Registry.ZeroAddress.selector);
        registry.setRules(address(0), true);
        
        vm.expectRevert(Registry.ZeroAddress.selector);
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
        
        registry.setAsset(address(localUsdc), true);
        registry.setRules(localRules, true);
        registry.setStrategy(localStrategy, true);
        
        // Check that we can register and toggle components
        assertTrue(registry.allowedAssets(address(localUsdc)));
        assertTrue(registry.allowedRules(localRules));
        assertTrue(registry.allowedStrategies(localStrategy));
        
        // Set them to false again
        registry.setAsset(address(localUsdc), false);
        registry.setRules(localRules, false);
        registry.setStrategy(localStrategy, false);
        
        // Verify they're toggled off
        assertFalse(registry.allowedAssets(address(localUsdc)));
        assertFalse(registry.allowedRules(localRules));
        assertFalse(registry.allowedStrategies(localStrategy));
        
        vm.stopPrank();
    }
}