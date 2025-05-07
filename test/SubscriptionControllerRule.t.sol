// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
// import {SubscriptionController} from "../src/controllers/SubscriptionController.sol";
// import {ISubscriptionController} from "../src/controllers/ISubscriptionController.sol";
// import {SubscriptionControllerHook} from "../src/hooks/SubscriptionControllerHook.sol";
// import {IHook} from "../src/hooks/IHook.sol";
// import {tRWA} from "../src/token/tRWA.sol";
// import {RulesEngine} from "../src/hooks/RulesEngine.sol";
// import {MockStrategy} from "../src/mocks/MockStrategy.sol";
// import {RoleManager} from "../src/auth/RoleManager.sol";

// /**
//  * @title SubscriptionControllerHookTest
//  * @notice Tests for the SubscriptionControllerHook
//  */
// contract SubscriptionControllerHookTest is BaseFountfiTest {
//     // Test contracts
//     SubscriptionController public controller;
//     SubscriptionControllerHook public controllerHook;
//     tRWA public token;
//     MockStrategy public strategy;
//     RoleManager public roleManager;

//     function setUp() public override {
//         super.setUp();

//         // ===== IMPORTANT: first deploy any MockRoleManager needed =====
//         // Deploy role manager
//         vm.startPrank(owner);
//         roleManager = new RoleManager();
//         roleManager.initializeRegistry(address(this));

//         // Create additional admin addresses for the subscription controller
//         address[] memory managers = new address[](1);
//         managers[0] = admin;

//         // Deploy subscription controller
//         controller = new SubscriptionController(
//             owner,
//             managers
//         );

//         // Deploy a mock tRWA setup
//         MockStrategy mockStrat = new MockStrategy(owner);
//         mockStrat.initialize(
//             "Test Token",
//             "TT",
//             owner,
//             address(usdc),
//             6,
//             ""
//         );

//         // Store the references
//         strategy = mockStrat;
//         token = tRWA(strategy.sToken());

//         // Add the STRATEGY_ADMIN role so that strategy can modify the token
//         roleManager.grantRole(address(strategy), roleManager.STRATEGY_ADMIN());

//         // Set the controller on the token (this should work now)
//         strategy.callStrategyToken(
//             abi.encodeCall(tRWA.setController, (address(controller)))
//         );

//         // Deploy controller hook
//         controllerHook = new SubscriptionControllerHook(address(controller));
//         vm.stopPrank();
//     }

//     function test_Constructor() public {
//         // Verify controller reference
//         assertEq(address(controllerHook.controller()), address(controller), "Controller address mismatch");

//         // Verify constructor reverts with zero address
//         vm.startPrank(owner);
//         vm.expectRevert(SubscriptionControllerHook.InvalidController.selector);
//         new SubscriptionControllerHook(address(0));
//         vm.stopPrank();
//     }

//     function test_OnBeforeDeposit_WithoutActiveRound() public {
//         vm.startPrank(owner);

//         // Evaluate deposit without an active round
//         IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice
//         );

//         // Verify result (should be rejected)
//         assertFalse(result.approved, "Deposit should be rejected without active round");
//         assertEq(result.reason, "No active subscription round", "Rejection reason mismatch");

//         vm.stopPrank();
//     }

//     function test_OnBeforeDeposit_WithActiveRound() public {
//         vm.startPrank(owner);

//         // Open a subscription round
//         controller.openSubscriptionRound(
//             "Round 1",
//             block.timestamp,
//             block.timestamp + 7 days,
//             100
//         );

//         // Evaluate deposit with active round
//         IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice
//         );

//         // Verify result (should be approved)
//         assertTrue(result.approved, "Deposit should be approved with active round");
//         assertEq(result.reason, "", "Approval reason should be empty");

//         vm.stopPrank();
//     }

//     function test_OnBeforeDeposit_RoundFull() public {
//         vm.startPrank(owner);

//         // Open a subscription round with capacity 1
//         controller.openSubscriptionRound(
//             "Round 1",
//             block.timestamp,
//             block.timestamp + 7 days,
//             1
//         );

//         // Simulate a deposit via callback
//         vm.stopPrank();
//         vm.startPrank(address(token));
//         controller.operationCallback(
//             keccak256("DEPOSIT"),
//             true,
//             abi.encode(alice, 1000 * 1e6)
//         );
//         vm.stopPrank();

//         // Now try to evaluate another deposit
//         vm.startPrank(owner);
//         IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
//             address(token),
//             bob,
//             1000 * 1e6,
//             bob
//         );

//         // Verify result (should be rejected due to capacity)
//         assertFalse(result.approved, "Deposit should be rejected when round is full");
//         assertEq(result.reason, "Subscription round capacity reached", "Rejection reason mismatch");

//         vm.stopPrank();
//     }

//     function test_OnBeforeDeposit_ExpiredRound() public {
//         vm.startPrank(owner);

//         // Open a subscription round
//         controller.openSubscriptionRound(
//             "Round 1",
//             block.timestamp,
//             block.timestamp + 7 days,
//             100
//         );

//         // Fast forward past end time
//         vm.warp(block.timestamp + 8 days);

//         // Evaluate deposit with expired round
//         IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice
//         );

//         // Verify result (should be rejected)
//         assertFalse(result.approved, "Deposit should be rejected with expired round");
//         assertEq(result.reason, "Subscription round not active or expired", "Rejection reason mismatch");

//         vm.stopPrank();
//     }

//     function test_OnBeforeWithdraw_NotSupported() public {
//         vm.startPrank(owner);

//         // The hook should reject withdrawals as it doesn't support them
//         IHook.HookOutput memory result = controllerHook.onBeforeWithdraw(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice,
//             alice
//         );

//         // Verify result (should be rejected)
//         assertFalse(result.approved, "Withdraw should be rejected");
//         assertEq(result.reason, "SubscriptionControllerHook does not evaluate withdrawals", "Rejection reason mismatch");

//         vm.stopPrank();
//     }

//     function test_OnBeforeTransfer_NotSupported() public {
//         vm.startPrank(owner);

//         // The hook should reject transfers as it doesn't support them
//         IHook.HookOutput memory result = controllerHook.onBeforeTransfer(
//             address(token),
//             alice,
//             bob,
//             1000 * 1e6
//         );

//         // Verify result (should be rejected)
//         assertFalse(result.approved, "Transfer should be rejected");
//         assertEq(result.reason, "SubscriptionControllerHook does not evaluate transfers", "Rejection reason mismatch");

//         vm.stopPrank();
//     }

//     function test_RulesEngine_Integration() public {
//         vm.startPrank(owner);

//         // Open a subscription round
//         controller.openSubscriptionRound(
//             "Round 1",
//             block.timestamp,
//             block.timestamp + 7 days,
//             100
//         );

//         // Get direct evaluation from the controller hook
//         IHook.HookOutput memory result = controllerHook.onBeforeDeposit(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice
//         );

//         // Verify result (should be approved)
//         assertTrue(result.approved, "Deposit should be approved with active round");
//         assertEq(result.reason, "", "Approval reason should be empty");

//         // Now close the round
//         controller.closeSubscriptionRound();

//         // Re-evaluate deposit after closing round
//         result = controllerHook.onBeforeDeposit(
//             address(token),
//             alice,
//             1000 * 1e6,
//             alice
//         );

//         // Verify result (should be rejected)
//         assertFalse(result.approved, "Deposit should be rejected after round closed");
//         assertEq(result.reason, "Subscription round not active or expired", "Rejection reason mismatch");

//         vm.stopPrank();
//     }
// }