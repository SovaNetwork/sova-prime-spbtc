// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {RulesEngine} from "../src/hooks/RulesEngine.sol";
import {KycRulesHook} from "../src/hooks/KycRulesHook.sol";
import {MockSubscriptionHook} from "../src/mocks/MockSubscriptionHook.sol";
import {MockCappedSubscriptionHook} from "../src/mocks/MockCappedSubscriptionHook.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";

contract HooksTest is BaseFountfiTest {
    RulesEngine public rulesEngine;
    KycRulesHook public kycRules;
    MockSubscriptionHook public subHook;
    MockCappedSubscriptionHook public cappedHook;

    MockRoleManager public mockRoleManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy mock role manager
        mockRoleManager = new MockRoleManager(owner);

        // Deploy hooks
        rulesEngine = new RulesEngine(address(mockRoleManager));
        kycRules = new KycRulesHook(address(mockRoleManager)); // Default deny with role manager
        subHook = new MockSubscriptionHook(owner, true, true); // Enforce approval, initially open
        cappedHook = new MockCappedSubscriptionHook(10_000 * 10**6, true, "Test rejection");

        // Grant owner the necessary roles
        // MockRoleManager has different role structure
        // We'll make sure owner has all needed roles
        mockRoleManager.grantRole(owner, mockRoleManager.PROTOCOL_ADMIN());
        mockRoleManager.grantRole(owner, mockRoleManager.KYC_ADMIN());
        // No direct RULES_ADMIN in MockRoleManager, just use separate KYC_ADMIN role
        // Then the specific operator role
        mockRoleManager.grantRole(owner, mockRoleManager.KYC_OPERATOR());

        vm.stopPrank();
    }

    // === KYC Rules Tests ===

    function test_KycRules_AllowDeny() public {
        // Verify default is deny
        assertFalse(kycRules.isAllowed(alice));

        // Allow Alice
        vm.prank(owner);
        kycRules.allow(alice);

        // Verify Alice is allowed
        assertTrue(kycRules.isAllowed(alice));

        // Deny Alice
        vm.prank(owner);
        kycRules.deny(alice);

        // Verify Alice is denied
        assertFalse(kycRules.isAllowed(alice));

        // Reset address
        vm.prank(owner);
        kycRules.reset(alice);

        // Verify Alice is back to default (deny)
        assertFalse(kycRules.isAllowed(alice));
    }

    function test_KycRules_TransferRules() public {
        // Setup KYC status
        vm.startPrank(owner);
        kycRules.allow(alice);
        kycRules.allow(bob);
        vm.stopPrank();

        // Test transfer between allowed addresses
        IHook.HookOutput memory result = kycRules.onBeforeTransfer(
            address(0), alice, bob, 100
        );

        assertTrue(result.approved);
        assertEq(result.reason, "");

        // Deny Charlie
        vm.prank(owner);
        kycRules.deny(charlie);

        // Test transfer to denied address
        result = kycRules.onBeforeTransfer(
            address(0), alice, charlie, 100
        );

        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");

        // Test transfer from denied address
        result = kycRules.onBeforeTransfer(
            address(0), charlie, alice, 100
        );

        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
    }

    // === Subscription Hook Tests ===

    function test_SubscriptionHook_Approval() public {
        // Test initial state
        IHook.HookOutput memory result = subHook.onBeforeDeposit(
            address(0), alice, 100, alice
        );

        // Should fail because alice is not approved
        assertFalse(result.approved);
        assertEq(result.reason, "Address is not approved for subscription");

        // Approve alice
        vm.prank(owner);
        subHook.setSubscriber(alice, true);

        // Try deposit again
        result = subHook.onBeforeDeposit(
            address(0), alice, 100, alice
        );

        // Should succeed now
        assertTrue(result.approved);

        // Close subscriptions
        vm.prank(owner);
        subHook.setSubscriptionStatus(false);

        // Try deposit again
        result = subHook.onBeforeDeposit(
            address(0), alice, 100, alice
        );

        // Should fail because subscriptions closed
        assertFalse(result.approved);
        assertEq(result.reason, "Subscriptions are closed");

        // Disable approval enforcement
        vm.startPrank(owner);
        subHook.setSubscriptionStatus(true); // Open again
        subHook.setEnforceApproval(false);
        vm.stopPrank();

        // Try with unapproved user
        result = subHook.onBeforeDeposit(
            address(0), bob, 100, bob
        );

        // Should succeed because enforcement is off
        assertTrue(result.approved);
    }

    function test_SubscriptionHook_BatchApproval() public {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;

        // Batch approve
        vm.prank(owner);
        subHook.batchSetSubscribers(users, true);

        // Check all are approved
        IHook.HookOutput memory result;

        result = subHook.onBeforeDeposit(address(0), alice, 100, alice);
        assertTrue(result.approved);

        result = subHook.onBeforeDeposit(address(0), bob, 100, bob);
        assertTrue(result.approved);

        result = subHook.onBeforeDeposit(address(0), charlie, 100, charlie);
        assertTrue(result.approved);
    }

    // === Capped Subscription Hook Tests ===

    function test_CappedHook_Limits() public {
        // For the MockCappedSubscriptionHook, we'll test the basic cap management functions

        // Initial cap should be 10_000 * 10**6
        assertEq(cappedHook.maxSubscriptionSize(), 10_000 * 10**6);

        // Update cap
        cappedHook.setMaxSubscriptionSize(20_000 * 10**6);

        // Verify cap was updated
        assertEq(cappedHook.maxSubscriptionSize(), 20_000 * 10**6);
    }

    function test_CappedHook_Deposit() public {
        // Initial cap is 10_000 * 10**6

        // Test deposit within cap
        IHook.HookOutput memory result = cappedHook.onBeforeDeposit(
            address(0), bob, 5_000 * 10**6, bob
        );

        assertTrue(result.approved);

        // Check used cap
        assertEq(cappedHook.totalSubscriptions(), 5_000 * 10**6);

        // Test deposit that exceeds cap
        result = cappedHook.onBeforeDeposit(
            address(0), bob, 6_000 * 10**6, bob
        );

        assertFalse(result.approved);
        assertEq(result.reason, "Subscription would exceed maximum capacity");

        // Total subscriptions should be unchanged
        assertEq(cappedHook.totalSubscriptions(), 5_000 * 10**6);
    }

    // === Rules Engine Tests ===

    function test_RulesEngine_Management() public {
        // First, mock the hasAllRoles function in the MockRoleManager
        // This needs to be fixed since our RulesEngine uses roleManager.RULES_ADMIN()
        vm.startPrank(owner);

        // The owner is already granted all roles in the MockRoleManager constructor
        // But we need to make sure it works with the RulesEngine's expected behavior

        // Add hooks to the RulesEngine
        rulesEngine.addHook(address(kycRules), 0);
        rulesEngine.addHook(address(subHook), 1);

        // Get all hook IDs
        bytes32[] memory hookIds = rulesEngine.getAllHookIds();
        assertEq(hookIds.length, 2, "Should have 2 hooks registered");

        // Disable a hook
        rulesEngine.disableHook(hookIds[0]);
        assertFalse(rulesEngine.isHookActive(hookIds[0]), "Hook should be disabled");

        // Enable a hook
        rulesEngine.enableHook(hookIds[0]);
        assertTrue(rulesEngine.isHookActive(hookIds[0]), "Hook should be enabled");

        // Change priority
        rulesEngine.changeHookPriority(hookIds[0], 2);
        assertEq(rulesEngine.getHookPriority(hookIds[0]), 2, "Priority should be updated");

        // Remove a hook
        rulesEngine.removeHook(hookIds[1]);
        hookIds = rulesEngine.getAllHookIds();
        assertEq(hookIds.length, 1, "Should have 1 hook after removal");

        vm.stopPrank();
    }

    function test_RulesEngine_Evaluation() public {
        vm.startPrank(owner);

        // Setup hooks
        kycRules.allow(alice);
        kycRules.allow(bob);
        subHook.setSubscriber(alice, true);

        // Add hooks to the RulesEngine
        rulesEngine.addHook(address(kycRules), 0);
        rulesEngine.addHook(address(subHook), 1);

        // Test evaluation for alice (should pass both hooks)
        IHook.HookOutput memory result = rulesEngine.onBeforeDeposit(
            address(0), alice, 100, alice
        );
        assertTrue(result.approved, "Alice should pass both hooks");

        // Deny bob in subscription rules (should fail on subHook)
        subHook.setSubscriber(bob, false);

        // Test evaluation for bob
        result = rulesEngine.onBeforeDeposit(
            address(0), bob, 100, bob
        );
        assertFalse(result.approved, "Bob should fail on subscription hook");
        assertTrue(bytes(result.reason).length > 0, "Reason should be provided");

        vm.stopPrank();
    }
}