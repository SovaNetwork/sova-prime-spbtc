// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {ReportedStrategy} from "../src/strategy/ReportedStrategy.sol";
import {MockHook} from "../src/mocks/MockHook.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";
import {Registry} from "../src/registry/Registry.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";

/**
 * @title HookRemovalTest
 * @notice Tests for the new hook removal functionality
 */
contract HookRemovalTest is Test {
    tRWA public token;
    ReportedStrategy public strategy;
    MockHook public hook1;
    MockHook public hook2;
    MockERC20 public asset;
    MockReporter public reporter;
    Registry public registry;
    RoleManager public roleManager;
    
    address public owner;
    address public manager;
    address public alice;

    function setUp() public {
        owner = makeAddr("owner");
        manager = makeAddr("manager");
        alice = makeAddr("alice");

        vm.startPrank(owner);

        // Deploy basic infrastructure
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));
        roleManager.initializeRegistry(address(registry));

        // Deploy asset and register it
        asset = new MockERC20("Test Asset", "TEST", 18);
        registry.setAsset(address(asset), 18);

        // Deploy reporter and strategy
        reporter = new MockReporter(1e18);
        ReportedStrategy strategyImpl = new ReportedStrategy();
        registry.setStrategy(address(strategyImpl), true);

        // Deploy strategy and token through registry
        bytes memory initData = abi.encode(address(reporter));
        (address strategyAddr, address tokenAddr) = registry.deploy(
            address(strategyImpl),
            "Test Token",
            "TEST",
            address(asset),
            manager,
            initData
        );

        strategy = ReportedStrategy(strategyAddr);
        token = tRWA(tokenAddr);

        vm.stopPrank();
        vm.startPrank(owner);

        // Deploy test hooks
        hook1 = new MockHook(true, "");
        hook2 = new MockHook(true, "");

        vm.stopPrank();
    }

    function test_AddAndRemoveHookBeforeOperations() public {
        vm.startPrank(address(strategy));

        // Add a hook
        token.addOperationHook(token.OP_DEPOSIT(), address(hook1));
        
        // Verify hook was added
        address[] memory hooks = token.getHooksForOperation(token.OP_DEPOSIT());
        assertEq(hooks.length, 1);
        assertEq(hooks[0], address(hook1));

        // Should be able to remove hook since no operations have occurred
        token.removeOperationHook(token.OP_DEPOSIT(), 0);

        // Verify hook was removed
        hooks = token.getHooksForOperation(token.OP_DEPOSIT());
        assertEq(hooks.length, 0);

        vm.stopPrank();
    }

    function test_CannotRemoveHookAfterOperations() public {
        vm.startPrank(address(strategy));
        
        // Add a hook
        token.addOperationHook(token.OP_DEPOSIT(), address(hook1));
        
        vm.stopPrank();

        // Perform a deposit operation
        vm.prank(owner);
        asset.mint(alice, 1000e18);
        vm.startPrank(alice);
        asset.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice);
        vm.stopPrank();

        // Now try to remove the hook - should fail
        vm.startPrank(address(strategy));
        
        bool success = false;
        try token.removeOperationHook(token.OP_DEPOSIT(), 0) {
            success = true;
        } catch {
            // Expected to revert
        }
        assertFalse(success, "Should not be able to remove hook after operations");
        
        vm.stopPrank();
    }

    function test_CanRemoveUnusedHookEvenIfOthersUsed() public {
        vm.startPrank(address(strategy));
        
        // Add two hooks
        token.addOperationHook(token.OP_DEPOSIT(), address(hook1));
        token.addOperationHook(token.OP_WITHDRAW(), address(hook2));
        
        vm.stopPrank();

        // Perform only a deposit operation (uses hook1 but not hook2)
        vm.prank(owner);
        asset.mint(alice, 1000e18);
        vm.startPrank(alice);
        asset.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice);
        vm.stopPrank();

        vm.startPrank(address(strategy));
        
        // Should not be able to remove the deposit hook (it was used)
        bool success = false;
        try token.removeOperationHook(token.OP_DEPOSIT(), 0) {
            success = true;
        } catch {
            // Expected to revert
        }
        assertFalse(success, "Should not be able to remove used deposit hook");

        // Should be able to remove the withdraw hook (it was not used)
        token.removeOperationHook(token.OP_WITHDRAW(), 0);
        
        // Verify withdraw hook was removed
        address[] memory withdrawHooks = token.getHooksForOperation(token.OP_WITHDRAW());
        assertEq(withdrawHooks.length, 0);

        vm.stopPrank();
    }

    function test_HookInfoTracking() public {
        vm.startPrank(address(strategy));
        
        // Add a hook
        uint256 blockNumber = block.number;
        token.addOperationHook(token.OP_DEPOSIT(), address(hook1));
        
        // Check hook info
        tRWA.HookInfo[] memory hookInfos = token.getHookInfoForOperation(token.OP_DEPOSIT());
        assertEq(hookInfos.length, 1);
        assertEq(address(hookInfos[0].hook), address(hook1));
        assertEq(hookInfos[0].addedAtBlock, blockNumber);
        assertFalse(hookInfos[0].hasProcessedOperations);
        
        vm.stopPrank();

        // Perform operation
        vm.prank(owner);
        asset.mint(alice, 1000e18);
        vm.startPrank(alice);
        asset.approve(registry.conduit(), 1000e18);
        token.deposit(1000e18, alice);
        vm.stopPrank();

        // Check that hook is now marked as having processed operations
        hookInfos = token.getHookInfoForOperation(token.OP_DEPOSIT());
        assertTrue(hookInfos[0].hasProcessedOperations);
    }

    function test_RemoveHookIndexValidation() public {
        vm.startPrank(address(strategy));
        
        // Test 1: Try to remove hook from empty list
        bool success = false;
        try token.removeOperationHook(token.OP_DEPOSIT(), 0) {
            success = true;
        } catch {
            // Expected to revert
        }
        assertFalse(success, "Should not be able to remove from empty list");

        // Add one hook
        token.addOperationHook(token.OP_DEPOSIT(), address(hook1));

        // Test 2: Try to remove with invalid index
        success = false;
        try token.removeOperationHook(token.OP_DEPOSIT(), 1) {
            success = true;
        } catch {
            // Expected to revert
        }
        assertFalse(success, "Should not be able to remove with invalid index");

        vm.stopPrank();
    }

    function test_AuthorizationCheck() public {
        // Test that non-strategy caller gets rejected
        vm.startPrank(alice);
        
        bool success = false;
        try token.removeOperationHook(token.OP_DEPOSIT(), 0) {
            success = true;
        } catch {
            // Expected to revert
        }
        assertFalse(success, "Non-strategy caller should be rejected");
        
        vm.stopPrank();
    }
}