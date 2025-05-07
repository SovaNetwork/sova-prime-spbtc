// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {SubscriptionController} from "../src/controllers/SubscriptionController.sol";
import {ISubscriptionController} from "../src/controllers/ISubscriptionController.sol";
import {SubscriptionControllerHook} from "../src/hooks/SubscriptionControllerHook.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";
import {RulesEngine} from "../src/hooks/RulesEngine.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";

/**
 * @title SubscriptionControllerTest
 * @notice Tests for the SubscriptionController
 */
contract SubscriptionControllerTest is BaseFountfiTest {
    // Test contracts
    SubscriptionController public controller;
    SubscriptionControllerHook public controllerHook;
    tRWA public token;
    MockStrategy public strategy;
    RulesEngine public rulesEngine;
    MockRoleManager public roleManager;

    // Test constants
    uint256 public constant SUBSCRIPTION_ADMIN_ROLE = 1 << 0;
    
    function setUp() public override {
        super.setUp();
        
        // ===== IMPORTANT: first deploy any MockRoleManager needed =====
        // Deploy role manager for strategy
        vm.startPrank(owner);
        roleManager = new MockRoleManager(owner);
        
        // Create managers list for the subscription controller
        address[] memory managers = new address[](2);
        managers[0] = admin;
        managers[1] = manager;
        
        // Deploy subscription controller with proper roles
        controller = new SubscriptionController(
            owner,
            managers
        );
        
        // Deploy a mock tRWA setup manually instead of using the helper
        MockStrategy mockStrat = new MockStrategy(owner);
        mockStrat.initialize(
            "Test Token",
            "TT", 
            owner,
            address(usdc),
            6,
            ""
        );
        
        // Store the references
        strategy = mockStrat;
        token = tRWA(strategy.sToken());
        
        // Add the STRATEGY_ADMIN role so that strategy can modify the token
        roleManager.grantRole(address(strategy), roleManager.STRATEGY_ADMIN());
        
        // Set the controller on the token (this should work now)
        strategy.callStrategyToken(
            abi.encodeCall(tRWA.setController, (address(controller)))
        );
        
        // Deploy controller hook
        controllerHook = new SubscriptionControllerHook(address(controller));
        
        // Add hook to token for all operations
        bytes32 opDeposit = keccak256("DEPOSIT_OPERATION");
        bytes32 opWithdraw = keccak256("WITHDRAW_OPERATION");
        bytes32 opTransfer = keccak256("TRANSFER_OPERATION");
        
        strategy.callStrategyToken(
            abi.encodeCall(tRWA.addOperationHook, (opDeposit, address(controllerHook)))
        );
        strategy.callStrategyToken(
            abi.encodeCall(tRWA.addOperationHook, (opWithdraw, address(controllerHook)))
        );
        strategy.callStrategyToken(
            abi.encodeCall(tRWA.addOperationHook, (opTransfer, address(controllerHook)))
        );
        vm.stopPrank();
    }
    
    function test_Controller_Constructor() public {
        // Verify roles were assigned correctly
        assertTrue(controller.hasRole(owner, SUBSCRIPTION_ADMIN_ROLE), "Owner should have admin role");
        assertTrue(controller.hasRole(admin, SUBSCRIPTION_ADMIN_ROLE), "Admin should have admin role");
        assertTrue(controller.hasRole(manager, SUBSCRIPTION_ADMIN_ROLE), "Manager should have admin role");
        
        // Verify non-authorized users don't have roles
        assertFalse(controller.hasRole(alice, SUBSCRIPTION_ADMIN_ROLE), "Alice should not have admin role");
    }
    
    function test_OpenSubscriptionRound() public {
        vm.startPrank(owner);
        
        string memory name = "Round 1";
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 7 days;
        uint256 capacity = 100;
        
        uint256 roundId = controller.openSubscriptionRound(name, startTime, endTime, capacity);
        
        // Verify round was created with correct ID
        assertEq(roundId, 1, "First round should have ID 1");
        
        // Verify round parameters
        ISubscriptionController.SubscriptionRound memory round = controller.getCurrentRound();
        assertEq(round.id, 1, "Round ID should be 1");
        assertEq(round.name, name, "Round name mismatch");
        assertEq(round.start, startTime, "Start time mismatch");
        assertEq(round.end, endTime, "End time mismatch");
        assertEq(round.capacity, capacity, "Capacity mismatch");
        assertEq(round.deposits, 0, "Initial deposits should be 0");
        assertTrue(round.active, "Round should be active");
        
        vm.stopPrank();
    }
    
    function test_CloseSubscriptionRound() public {
        vm.startPrank(owner);
        
        // Open a round first
        controller.openSubscriptionRound("Round 1", block.timestamp, block.timestamp + 7 days, 100);
        
        // Close the round
        controller.closeSubscriptionRound();
        
        // Verify round is inactive
        ISubscriptionController.SubscriptionRound memory round = controller.getCurrentRound();
        assertFalse(round.active, "Round should be inactive after closing");
        
        vm.stopPrank();
    }
    
    function test_IsRoundActive() public {
        vm.startPrank(owner);
        
        // Open a round
        uint256 roundId = controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            100
        );
        
        // Check round is active
        assertTrue(controller.isRoundActive(roundId), "Round should be active");
        
        // Close the round
        controller.closeSubscriptionRound();
        
        // Check round is inactive
        assertFalse(controller.isRoundActive(roundId), "Round should be inactive after closing");
        
        // Open another round with future start time
        uint256 futureRoundId = controller.openSubscriptionRound(
            "Future Round",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            100
        );
        
        // Check future round is not active yet
        assertFalse(controller.isRoundActive(futureRoundId), "Future round should not be active yet");
        
        // Warp to start time
        vm.warp(block.timestamp + 1 days + 1);
        
        // Check round is now active
        assertTrue(controller.isRoundActive(futureRoundId), "Round should be active after start time");
        
        // Warp past end time
        vm.warp(block.timestamp + 8 days);
        
        // Check round is no longer active
        assertFalse(controller.isRoundActive(futureRoundId), "Round should be inactive after end time");
        
        vm.stopPrank();
    }
    
    function test_ValidateDeposit() public {
        vm.startPrank(owner);
        
        // No active round
        (bool valid, string memory reason) = controller.validateDeposit(alice, 1000 * 1e6);
        assertFalse(valid, "Deposit should be invalid with no active round");
        assertEq(reason, "No active subscription round");
        
        // Open a round
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            2 // Low capacity to test limit
        );
        
        // Valid deposit
        (valid, reason) = controller.validateDeposit(alice, 1000 * 1e6);
        assertTrue(valid, "Deposit should be valid during active round");
        assertEq(reason, "");
        
        // Simulate two deposits - need to prank as token
        vm.stopPrank();
        vm.startPrank(address(token));
        
        controller.operationCallback(
            keccak256("DEPOSIT"),
            true,
            abi.encode(alice, 1000 * 1e6)
        );
        
        controller.operationCallback(
            keccak256("DEPOSIT"),
            true,
            abi.encode(bob, 1000 * 1e6)
        );
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Try deposit after capacity reached
        (valid, reason) = controller.validateDeposit(charlie, 1000 * 1e6);
        assertFalse(valid, "Deposit should be invalid after capacity reached");
        assertEq(reason, "Subscription round capacity reached");
        
        // Close the round
        controller.closeSubscriptionRound();
        
        // Try deposit with inactive round
        (valid, reason) = controller.validateDeposit(alice, 1000 * 1e6);
        assertFalse(valid, "Deposit should be invalid with inactive round");
        assertEq(reason, "Subscription round not active or expired");
        
        vm.stopPrank();
    }
    
    function test_OperationCallback() public {
        vm.startPrank(owner);
        
        // Open a round
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            100
        );
        
        // Verify initial state
        ISubscriptionController.SubscriptionRound memory round = controller.getCurrentRound();
        assertEq(round.deposits, 0, "Initial deposits should be 0");
        
        // Test valid callback from token
        vm.stopPrank();
        vm.startPrank(address(token));
        controller.operationCallback(
            keccak256("DEPOSIT"),
            true,
            abi.encode(alice, 1000 * 1e6)
        );
        vm.stopPrank();
        
        // Verify subscription was created
        vm.startPrank(owner);
        uint256[] memory aliceSubscriptions = controller.getUserSubscriptions(alice);
        assertEq(aliceSubscriptions.length, 1, "Alice should have 1 subscription");
        
        ISubscriptionController.Subscription memory subscription = controller.getSubscription(aliceSubscriptions[0]);
        assertEq(subscription.user, alice, "Subscription user should be Alice");
        assertEq(subscription.amount, 1000 * 1e6, "Subscription amount should match");
        assertEq(subscription.amountWithdrawn, 0, "Withdrawn amount should be 0");
        
        // Verify round was updated
        round = controller.getCurrentRound();
        assertEq(round.deposits, 1, "Deposits should be incremented");
        
        vm.stopPrank();
    }
    
    function test_AutoCloseExpiredRound() public {
        vm.startPrank(owner);
        
        // Open a round with short duration
        controller.openSubscriptionRound(
            "Short Round",
            block.timestamp,
            block.timestamp + 1 days,
            100
        );
        
        // Verify round is active
        ISubscriptionController.SubscriptionRound memory round = controller.getCurrentRound();
        assertTrue(round.active, "Round should be active");
        
        // Warp past end time
        vm.warp(block.timestamp + 2 days);
        
        // Make deposit which should auto-close the round
        (bool valid, string memory reason) = controller.validateDeposit(alice, 1000 * 1e6);
        assertFalse(valid, "Deposit should be invalid with expired round");
        assertEq(reason, "Subscription round not active or expired");
        
        // Alternatively, we can explicitly check with checkAndCloseExpiredRound
        bool closed = controller.checkAndCloseExpiredRound();
        assertTrue(closed, "Round should be closed due to expiry");
        
        // Verify round is now inactive
        round = controller.getCurrentRound();
        assertFalse(round.active, "Round should be inactive after expiry");
        
        vm.stopPrank();
    }
    
    function test_RoleManagement() public {
        vm.startPrank(owner);
        
        // Verify initial roles
        assertTrue(controller.hasRole(admin, SUBSCRIPTION_ADMIN_ROLE));
        assertFalse(controller.hasRole(alice, SUBSCRIPTION_ADMIN_ROLE));
        
        // Grant role to Alice
        controller.grantRole(alice, SUBSCRIPTION_ADMIN_ROLE);
        assertTrue(controller.hasRole(alice, SUBSCRIPTION_ADMIN_ROLE));
        
        // Revoke role from Admin
        controller.revokeRole(admin, SUBSCRIPTION_ADMIN_ROLE);
        assertFalse(controller.hasRole(admin, SUBSCRIPTION_ADMIN_ROLE));
        
        vm.stopPrank();
    }
    
    function test_OpenRound_Unauthorized() public {
        vm.startPrank(alice); // Alice doesn't have admin role by default
        
        // Attempt to open round should fail
        vm.expectRevert();
        controller.openSubscriptionRound("Round 1", block.timestamp, block.timestamp + 7 days, 100);
        
        vm.stopPrank();
    }
    
    function test_OpenRound_ValidationFailures() public {
        vm.startPrank(owner);
        
        // Invalid time range
        vm.expectRevert(ISubscriptionController.InvalidTimeRange.selector);
        controller.openSubscriptionRound("Invalid Round", block.timestamp, block.timestamp, 100);
        
        vm.expectRevert(ISubscriptionController.InvalidTimeRange.selector);
        controller.openSubscriptionRound("Invalid Round", block.timestamp + 100, block.timestamp, 100);
        
        // Invalid capacity
        vm.expectRevert(ISubscriptionController.InvalidCapacity.selector);
        controller.openSubscriptionRound("Invalid Round", block.timestamp, block.timestamp + 7 days, 0);
        
        // Cannot have two active rounds
        controller.openSubscriptionRound("Round 1", block.timestamp, block.timestamp + 7 days, 100);
        
        vm.expectRevert(ISubscriptionController.RoundAlreadyActive.selector);
        controller.openSubscriptionRound("Round 2", block.timestamp, block.timestamp + 7 days, 100);
        
        vm.stopPrank();
    }
    
    function test_CloseRound_NoActiveRound() public {
        vm.startPrank(owner);
        
        // No active round
        vm.expectRevert(ISubscriptionController.NoActiveRound.selector);
        controller.closeSubscriptionRound();
        
        vm.stopPrank();
    }
    
    function test_ControllerHook_Integration() public {
        // Test the subscription controller hook integration
        
        vm.startPrank(owner);
        
        // Open a round
        controller.openSubscriptionRound(
            "Round 1", 
            block.timestamp, 
            block.timestamp + 7 days, 
            100
        );
        
        // Test hook with active round
        IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        assertTrue(result.approved, "Deposit should be approved with active round");
        assertEq(result.reason, "", "Approval reason should be empty");
        
        // Test controller hook with no active round
        controller.closeSubscriptionRound();
        
        // Evaluation should fail with no active round
        result = controllerHook.onBeforeDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        assertFalse(result.approved, "Deposit should be rejected with no active round");
        assertEq(result.reason, "Subscription round not active or expired", "Rejection reason mismatch");
        
        // Now open an active round and try again
        controller.openSubscriptionRound(
            "Round 2", 
            block.timestamp, 
            block.timestamp + 7 days, 
            100
        );
        
        // Evaluation should succeed with active round
        result = controllerHook.onBeforeDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        assertTrue(result.approved, "Deposit should be approved with active round");
        assertEq(result.reason, "", "Approval reason should be empty");
        
        vm.stopPrank();
    }
}