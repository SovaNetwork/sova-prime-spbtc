// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {IRules} from "../src/rules/IRules.sol";

/**
 * @title KycRulesTest
 * @notice Test suite for KycRules contract with 100% coverage target
 */
contract KycRulesTest is BaseFountfiTest {
    KycRules public kycRulesDefaultDeny;
    KycRules public kycRulesDefaultAllow;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy rules with different default settings
        kycRulesDefaultDeny = new KycRules(owner, false); // Default deny
        kycRulesDefaultAllow = new KycRules(owner, true); // Default allow
        
        vm.stopPrank();
    }
    
    // Test constructor and initialization
    function test_Constructor() public {
        // Test with valid parameters
        vm.startPrank(owner);
        KycRules newRules = new KycRules(alice, true);
        vm.stopPrank();
        
        // Verify state
        assertTrue(newRules.defaultAllow());
        assertTrue(newRules.isAllowed(charlie)); // Should be allowed by default
        
        // Try creating with invalid admin address
        vm.startPrank(owner);
        vm.expectRevert("Invalid admin address");
        new KycRules(address(0), true);
        vm.stopPrank();
    }
    
    // Test defaultAllow flag effects
    function test_DefaultAllowBehavior() public {
        // Default deny rules
        assertFalse(kycRulesDefaultDeny.isAllowed(alice));
        
        // Default allow rules
        assertTrue(kycRulesDefaultAllow.isAllowed(alice));
        
        // Check operation-specific behaviors with default states
        IRules.RuleResult memory result;
        
        // Default deny: evaluateTransfer
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), alice, bob, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Default allow: evaluateTransfer
        result = kycRulesDefaultAllow.evaluateTransfer(address(0), alice, bob, 100);
        assertTrue(result.approved);
        assertEq(result.reason, "");
    }
    
    // Test allow address functionality with comprehensive checks
    function test_AllowAddress() public {
        // Setup
        address testUser = address(0x123);
        
        // Try allowing with non-owner
        vm.startPrank(alice);
        vm.expectRevert();
        kycRulesDefaultDeny.allowAddress(testUser);
        vm.stopPrank();
        
        // Test allow functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert("Invalid address");
        kycRulesDefaultDeny.allowAddress(address(0));
        
        // Try allowing a denied address
        kycRulesDefaultDeny.denyAddress(testUser);
        vm.expectRevert("Address is denied");
        kycRulesDefaultDeny.allowAddress(testUser);
        
        // Remove restriction and then allow
        kycRulesDefaultDeny.removeAddressRestriction(testUser);
        kycRulesDefaultDeny.allowAddress(testUser);
        
        vm.stopPrank();
        
        // Verify status
        assertTrue(kycRulesDefaultDeny.isAllowed(testUser));
        assertTrue(kycRulesDefaultDeny.isAddressAllowed(testUser));
        assertFalse(kycRulesDefaultDeny.isAddressDenied(testUser));
    }
    
    // Test deny address functionality with comprehensive checks
    function test_DenyAddress() public {
        // Setup
        address testUser = address(0x123);
        
        // Try denying with non-owner
        vm.startPrank(alice);
        vm.expectRevert();
        kycRulesDefaultAllow.denyAddress(testUser);
        vm.stopPrank();
        
        // Test deny functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert("Invalid address");
        kycRulesDefaultAllow.denyAddress(address(0));
        
        // Allow first, then deny to test flag changes
        kycRulesDefaultAllow.allowAddress(testUser);
        kycRulesDefaultAllow.denyAddress(testUser);
        
        vm.stopPrank();
        
        // Verify status
        assertFalse(kycRulesDefaultAllow.isAllowed(testUser));
        assertFalse(kycRulesDefaultAllow.isAddressAllowed(testUser));
        assertTrue(kycRulesDefaultAllow.isAddressDenied(testUser));
    }
    
    // Test remove address restriction functionality
    function test_RemoveAddressRestriction() public {
        // Setup
        address testUser = address(0x123);
        
        // Try removing restriction with non-owner
        vm.startPrank(alice);
        vm.expectRevert();
        kycRulesDefaultDeny.removeAddressRestriction(testUser);
        vm.stopPrank();
        
        // Test functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert("Invalid address");
        kycRulesDefaultDeny.removeAddressRestriction(address(0));
        
        // Setup initial state
        kycRulesDefaultDeny.allowAddress(testUser);
        assertTrue(kycRulesDefaultDeny.isAllowed(testUser));
        
        // Remove restriction
        kycRulesDefaultDeny.removeAddressRestriction(testUser);
        
        vm.stopPrank();
        
        // Verify status (should be back to default)
        assertFalse(kycRulesDefaultDeny.isAllowed(testUser));
        assertFalse(kycRulesDefaultDeny.isAddressAllowed(testUser));
        assertFalse(kycRulesDefaultDeny.isAddressDenied(testUser));
        
        // Also test with a denied address
        vm.startPrank(owner);
        kycRulesDefaultDeny.denyAddress(alice);
        kycRulesDefaultDeny.removeAddressRestriction(alice);
        vm.stopPrank();
        
        assertFalse(kycRulesDefaultDeny.isAddressDenied(alice));
    }
    
    // Test setDefaultAllow functionality
    function test_SetDefaultAllow() public {
        // Try with non-owner
        vm.startPrank(alice);
        vm.expectRevert();
        kycRulesDefaultDeny.setDefaultAllow(true);
        vm.stopPrank();
        
        // Verify initial state
        assertFalse(kycRulesDefaultDeny.defaultAllow());
        assertFalse(kycRulesDefaultDeny.isAllowed(charlie));
        
        // Change default state
        vm.startPrank(owner);
        kycRulesDefaultDeny.setDefaultAllow(true);
        vm.stopPrank();
        
        // Verify change
        assertTrue(kycRulesDefaultDeny.defaultAllow());
        assertTrue(kycRulesDefaultDeny.isAllowed(charlie));
    }
    
    // Test isAllowed functionality
    function test_IsAllowed() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRulesDefaultDeny.allowAddress(alice);
        kycRulesDefaultDeny.denyAddress(bob);
        vm.stopPrank();
        
        // Check behavior for all cases
        assertTrue(kycRulesDefaultDeny.isAllowed(alice)); // Explicitly allowed
        assertFalse(kycRulesDefaultDeny.isAllowed(bob)); // Explicitly denied
        assertFalse(kycRulesDefaultDeny.isAllowed(charlie)); // Follows default (deny)
        
        // Change default and verify
        vm.prank(owner);
        kycRulesDefaultDeny.setDefaultAllow(true);
        
        assertTrue(kycRulesDefaultDeny.isAllowed(alice)); // Still allowed
        assertFalse(kycRulesDefaultDeny.isAllowed(bob)); // Still denied
        assertTrue(kycRulesDefaultDeny.isAllowed(charlie)); // Now follows default (allow)
    }
    
    // Test evaluateTransfer with all possible KYC combinations
    function test_EvaluateTransfer_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRulesDefaultDeny.allowAddress(alice);
        kycRulesDefaultDeny.allowAddress(bob);
        kycRulesDefaultDeny.denyAddress(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // Both allowed
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), alice, bob, 100);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Sender denied
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), charlie, bob, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Receiver denied
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), alice, charlie, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Both denied
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), charlie, charlie, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Default deny (unrestricted address)
        address unrestrictedUser = address(0x456);
        result = kycRulesDefaultDeny.evaluateTransfer(address(0), alice, unrestrictedUser, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
    }
    
    // Test evaluateDeposit with all possible KYC combinations
    function test_EvaluateDeposit_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRulesDefaultDeny.allowAddress(alice);
        kycRulesDefaultDeny.allowAddress(bob);
        kycRulesDefaultDeny.denyAddress(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // Both allowed
        result = kycRulesDefaultDeny.evaluateDeposit(address(0), alice, 100, bob);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Sender denied
        result = kycRulesDefaultDeny.evaluateDeposit(address(0), charlie, 100, bob);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Receiver denied
        result = kycRulesDefaultDeny.evaluateDeposit(address(0), alice, 100, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Both denied
        result = kycRulesDefaultDeny.evaluateDeposit(address(0), charlie, 100, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Default deny (unrestricted address)
        address unrestrictedUser = address(0x456);
        result = kycRulesDefaultDeny.evaluateDeposit(address(0), alice, 100, unrestrictedUser);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
    }
    
    // Test evaluateWithdraw with all possible KYC combinations
    function test_EvaluateWithdraw_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRulesDefaultDeny.allowAddress(alice);
        kycRulesDefaultDeny.allowAddress(bob);
        kycRulesDefaultDeny.denyAddress(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // All addresses allowed
        result = kycRulesDefaultDeny.evaluateWithdraw(address(0), alice, 100, bob, alice);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // User (initiator) denied
        result = kycRulesDefaultDeny.evaluateWithdraw(address(0), charlie, 100, bob, alice);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Owner denied
        result = kycRulesDefaultDeny.evaluateWithdraw(address(0), alice, 100, bob, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: owner");
        
        // Receiver denied
        result = kycRulesDefaultDeny.evaluateWithdraw(address(0), alice, 100, charlie, alice);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Default deny (unrestricted addresses)
        address unrestrictedUser = address(0x456);
        result = kycRulesDefaultDeny.evaluateWithdraw(address(0), alice, 100, bob, unrestrictedUser);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: owner");
    }
    
    // Integration test for KYC rules with different default states
    function test_KycRules_DifferentDefaults() public {
        // Set up a comparable state for both contracts
        vm.startPrank(owner);
        
        // Allow and deny the same addresses in both contracts
        kycRulesDefaultDeny.allowAddress(alice);
        kycRulesDefaultAllow.allowAddress(alice);
        
        kycRulesDefaultDeny.denyAddress(bob);
        kycRulesDefaultAllow.denyAddress(bob);
        
        vm.stopPrank();
        
        // Explicitly allowed addresses should be allowed in both contracts
        assertTrue(kycRulesDefaultDeny.isAllowed(alice));
        assertTrue(kycRulesDefaultAllow.isAllowed(alice));
        
        // Explicitly denied addresses should be denied in both contracts
        assertFalse(kycRulesDefaultDeny.isAllowed(bob));
        assertFalse(kycRulesDefaultAllow.isAllowed(bob));
        
        // Unrestricted addresses should follow default
        assertFalse(kycRulesDefaultDeny.isAllowed(charlie));
        assertTrue(kycRulesDefaultAllow.isAllowed(charlie));
    }
}