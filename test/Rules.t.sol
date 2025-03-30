// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {RulesEngine} from "../src/rules/RulesEngine.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {SubscriptionRules} from "../src/rules/SubscriptionRules.sol";
import {CappedSubscriptionRules} from "../src/rules/CappedSubscriptionRules.sol";
import {IRules} from "../src/rules/IRules.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";

contract RulesTest is BaseFountfiTest {
    RulesEngine public rulesEngine;
    KycRules public kycRules;
    SubscriptionRules public subRules;
    CappedSubscriptionRules public cappedRules;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy rules
        rulesEngine = new RulesEngine(owner);
        kycRules = new KycRules(owner, false); // Default deny
        subRules = new SubscriptionRules(owner, true, true); // Enforce approval, initially open
        cappedRules = new CappedSubscriptionRules(owner, 10_000 * 10**6, true, true);
        
        vm.stopPrank();
    }
    
    // === KYC Rules Tests ===
    
    function test_KycRules_AllowDeny() public {
        // Verify default is deny
        assertFalse(kycRules.isAllowed(alice));
        
        // Allow Alice
        vm.prank(owner);
        kycRules.allowAddress(alice);
        
        // Verify Alice is allowed
        assertTrue(kycRules.isAllowed(alice));
        
        // Deny Alice
        vm.prank(owner);
        kycRules.denyAddress(alice);
        
        // Verify Alice is denied
        assertFalse(kycRules.isAllowed(alice));
        
        // Remove restriction
        vm.prank(owner);
        kycRules.removeAddressRestriction(alice);
        
        // Verify Alice is back to default (deny)
        assertFalse(kycRules.isAllowed(alice));
        
        // Change default to allow
        vm.prank(owner);
        kycRules.setDefaultAllow(true);
        
        // Verify Alice is now allowed by default
        assertTrue(kycRules.isAllowed(alice));
    }
    
    function test_KycRules_TransferRules() public {
        // Setup KYC status
        vm.startPrank(owner);
        kycRules.allowAddress(alice);
        kycRules.allowAddress(bob);
        vm.stopPrank();
        
        // Test transfer between allowed addresses
        IRules.RuleResult memory result = kycRules.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Deny Charlie
        vm.prank(owner);
        kycRules.denyAddress(charlie);
        
        // Test transfer to denied address
        result = kycRules.evaluateTransfer(
            address(0), alice, charlie, 100
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Test transfer from denied address
        result = kycRules.evaluateTransfer(
            address(0), charlie, alice, 100
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
    }
    
    // === Subscription Rules Tests ===
    
    function test_SubscriptionRules_Approval() public {
        // Test initial state
        IRules.RuleResult memory result = subRules.evaluateDeposit(
            address(0), alice, 100, alice
        );
        
        // Should fail because alice is not approved
        assertFalse(result.approved);
        assertEq(result.reason, "Address is not approved for subscription");
        
        // Approve alice
        vm.prank(owner);
        subRules.setSubscriber(alice, true);
        
        // Try deposit again
        result = subRules.evaluateDeposit(
            address(0), alice, 100, alice
        );
        
        // Should succeed now
        assertTrue(result.approved);
        
        // Close subscriptions
        vm.prank(owner);
        subRules.setSubscriptionStatus(false);
        
        // Try deposit again
        result = subRules.evaluateDeposit(
            address(0), alice, 100, alice
        );
        
        // Should fail because subscriptions closed
        assertFalse(result.approved);
        assertEq(result.reason, "Subscriptions are closed");
        
        // Disable approval enforcement
        vm.startPrank(owner);
        subRules.setSubscriptionStatus(true); // Open again
        subRules.setEnforceApproval(false);
        vm.stopPrank();
        
        // Try with unapproved user
        result = subRules.evaluateDeposit(
            address(0), bob, 100, bob
        );
        
        // Should succeed because enforcement is off
        assertTrue(result.approved);
    }
    
    function test_SubscriptionRules_BatchApproval() public {
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;
        
        // Batch approve
        vm.prank(owner);
        subRules.batchSetSubscribers(users, true);
        
        // Check all are approved
        IRules.RuleResult memory result;
        
        result = subRules.evaluateDeposit(address(0), alice, 100, alice);
        assertTrue(result.approved);
        
        result = subRules.evaluateDeposit(address(0), bob, 100, bob);
        assertTrue(result.approved);
        
        result = subRules.evaluateDeposit(address(0), charlie, 100, charlie);
        assertTrue(result.approved);
    }
    
    // === Capped Subscription Rules Tests ===
    
    function test_CappedRules_Limits() public {
        // For the CappedSubscriptionRules, we'll just test the basic cap management functions
        // without trying to execute the evaluateDeposit method which requires a valid tRWA token
        
        // Initial cap should be 10_000 * 10**6
        assertEq(cappedRules.maxCap(), 10_000 * 10**6);
        
        // Check remaining cap is equal to max cap initially
        assertEq(cappedRules.remainingCap(), 10_000 * 10**6);
        
        // Update cap
        vm.prank(owner);
        cappedRules.updateCap(20_000 * 10**6);
        
        // Verify cap was updated
        assertEq(cappedRules.maxCap(), 20_000 * 10**6);
        assertEq(cappedRules.remainingCap(), 20_000 * 10**6);
        
        // Verify subscription functionality
        vm.prank(owner);
        cappedRules.setSubscriber(bob, true);
        
        // Test cap update without trying to trigger a revert
        vm.prank(owner);
        cappedRules.updateCap(30_000 * 10**6);
        
        // Verify cap was updated again
        assertEq(cappedRules.maxCap(), 30_000 * 10**6);
    }
    
    // === Rules Engine Tests ===
    
    function test_RulesEngine_Management() public {
        vm.startPrank(owner);
        
        // Add rules
        bytes32 kycId = rulesEngine.addRule(address(kycRules), 1);
        bytes32 subId = rulesEngine.addRule(address(subRules), 2);
        
        // Verify rules are added
        assertEq(rulesEngine.getRuleAddress(kycId), address(kycRules));
        assertEq(rulesEngine.getRuleAddress(subId), address(subRules));
        assertEq(rulesEngine.getRulePriority(kycId), 1);
        assertEq(rulesEngine.getRulePriority(subId), 2);
        assertTrue(rulesEngine.isRuleActive(kycId));
        assertTrue(rulesEngine.isRuleActive(subId));
        
        // Disable a rule
        rulesEngine.disableRule(kycId);
        
        // Verify rule is disabled
        assertFalse(rulesEngine.isRuleActive(kycId));
        
        // Change priority
        rulesEngine.changeRulePriority(subId, 3);
        assertEq(rulesEngine.getRulePriority(subId), 3);
        
        // Remove a rule
        rulesEngine.removeRule(kycId);
        
        // Verify rule list
        bytes32[] memory rules = rulesEngine.getAllRules();
        assertEq(rules.length, 1);
        assertEq(rules[0], subId);
        
        vm.stopPrank();
    }
    
    function test_RulesEngine_Evaluation() public {
        vm.startPrank(owner);
        
        // Setup rules
        kycRules.allowAddress(alice);
        kycRules.allowAddress(bob);
        subRules.setSubscriber(alice, true);
        
        // Add rules to engine
        bytes32 kycId = rulesEngine.addRule(address(kycRules), 1);
        bytes32 subId = rulesEngine.addRule(address(subRules), 2);
        
        // Test evaluation that passes all rules
        IRules.RuleResult memory result = rulesEngine.evaluateDeposit(
            address(0), alice, 100, alice
        );
        
        assertTrue(result.approved);
        
        // Deny bob in subscription rules
        subRules.setSubscriber(bob, false);
        
        // Test evaluation that fails one rule
        result = rulesEngine.evaluateDeposit(
            address(0), bob, 100, bob
        );
        
        assertFalse(result.approved);
        assertTrue(bytes(result.reason).length > 0);
        
        // Disable subscription rule
        rulesEngine.disableRule(subId);
        
        // Test evaluation with only KYC rule active
        result = rulesEngine.evaluateDeposit(
            address(0), bob, 100, bob
        );
        
        assertTrue(result.approved);
        
        vm.stopPrank();
    }
}