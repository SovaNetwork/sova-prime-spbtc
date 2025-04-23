// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";

/**
 * @title RegistryTest
 * @notice Complete test for the Registry contract
 */
contract RegistryFullTest is Test {
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
        
        // Deploy registry
        vm.startPrank(owner);
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));
        
        // Deploy mock contracts
        asset = new MockERC20("USD Coin", "USDC", 6);
        rules = new MockRules(true, "Mock rejection");
        strategyImpl = new MockStrategy(owner);
        
        // Grant roles
        roleManager.grantRole(owner, roleManager.PROTOCOL_ADMIN());
        roleManager.grantRole(owner, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(owner, roleManager.RULES_ADMIN());
        
        vm.stopPrank();
    }
    
    // Test constructor and initialization
    function test_Constructor() public {
        // Just verify initialization succeeded
        assertTrue(address(registry) != address(0));
        assertTrue(address(roleManager) != address(0));
    }
    
    // Test registration and toggling
    function test_Registration() public {
        vm.startPrank(owner);
        
        // Test strategy registration
        registry.setStrategy(address(strategyImpl), true);
        assertTrue(registry.allowedStrategies(address(strategyImpl)));
        
        // Test strategy deregistration
        registry.setStrategy(address(strategyImpl), false);
        assertFalse(registry.allowedStrategies(address(strategyImpl)));
        
        // Test rules registration
        registry.setRules(address(rules), true);
        assertTrue(registry.allowedRules(address(rules)));
        
        // Test rules deregistration
        registry.setRules(address(rules), false);
        assertFalse(registry.allowedRules(address(rules)));
        
        // Test asset registration
        registry.setAsset(address(asset), true);
        assertTrue(registry.allowedAssets(address(asset)));
        
        // Test asset deregistration
        registry.setAsset(address(asset), false);
        assertFalse(registry.allowedAssets(address(asset)));
        
        vm.stopPrank();
    }
    
    // Test deploy functionality
    function test_Deploy() public {
        vm.startPrank(owner);
        
        // Register components
        registry.setStrategy(address(strategyImpl), true);
        registry.setRules(address(rules), true);
        registry.setAsset(address(asset), true);
        
        // Deploy a strategy
        bytes memory initData = ""; // Empty init data for MockStrategy
        (address deployedStrategy, address deployedToken) = registry.deploy(
            "Test Token",
            "TEST",
            address(strategyImpl),
            address(asset),
            address(rules),
            manager,
            initData
        );
        
        // Verify deployment
        assertTrue(deployedStrategy != address(0));
        assertTrue(deployedToken != address(0));
        
        vm.stopPrank();
    }
}