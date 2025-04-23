// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {KycRules} from "../src/rules/KycRules.sol";
import {IRules} from "../src/rules/IRules.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";

/**
 * @title KycRulesTest
 * @notice Test suite for KycRules contract with 100% coverage target
 */
contract KycRulesTest is BaseFountfiTest {
    KycRules public kycRules;
    MockRoleManager public mockRoleManager;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy the mock role manager with owner as admin
        mockRoleManager = new MockRoleManager(owner);
        
        // Deploy rules with mock role manager
        kycRules = new KycRules(address(mockRoleManager));
        
        // Grant KYC roles to the owner for testing
        mockRoleManager.grantRole(owner, mockRoleManager.KYC_ADMIN());
        mockRoleManager.grantRole(owner, mockRoleManager.KYC_OPERATOR());
        
        vm.stopPrank();
    }
    
    // Test constructor and initialization
    function test_Constructor() public {
        // Test with valid parameters
        vm.startPrank(owner);
        MockRoleManager newRoleManager = new MockRoleManager(alice);
        KycRules newRules = new KycRules(address(newRoleManager));
        vm.stopPrank();
        
        // Verify state
        assertFalse(newRules.isAllowed(charlie)); // Should be denied by default
        
        // Try creating with invalid role manager address
        vm.startPrank(owner);
        vm.expectRevert(); // Just expect any revert, the specific error format is implementation-specific
        new KycRules(address(0));
        vm.stopPrank();
    }
    
    // Test default deny behavior
    function test_DefaultDenyBehavior() public {
        // By default addresses are denied
        assertFalse(kycRules.isAllowed(alice));
        
        // Check operation-specific behaviors with default deny
        IRules.RuleResult memory result;
        
        // Default deny: evaluateTransfer
        result = kycRules.evaluateTransfer(address(0), alice, bob, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
    }
    
    // Test allow functionality with comprehensive checks
    function test_Allow() public {
        // Setup
        address testUser = address(0x123);
        
        // Try allowing with non-authorized address
        vm.startPrank(alice);
        vm.expectRevert(); // Just expect any revert
        kycRules.allow(testUser);
        vm.stopPrank();
        
        // Test allow functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.allow(address(0));
        
        // Try allowing a denied address
        kycRules.deny(testUser);
        vm.expectRevert(KycRules.AddressAlreadyDenied.selector);
        kycRules.allow(testUser);
        
        // Reset address and then allow
        kycRules.reset(testUser);
        kycRules.allow(testUser);
        
        vm.stopPrank();
        
        // Verify status
        assertTrue(kycRules.isAllowed(testUser));
        assertTrue(kycRules.isAddressAllowed(testUser));
        assertFalse(kycRules.isAddressDenied(testUser));
    }
    
    // Test deny functionality with comprehensive checks
    function test_Deny() public {
        // Setup
        address testUser = address(0x123);
        
        // Try denying with non-authorized address
        vm.startPrank(alice);
        vm.expectRevert(); // Just expect any revert
        kycRules.deny(testUser);
        vm.stopPrank();
        
        // Test deny functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.deny(address(0));
        
        // Allow first, then deny to test flag changes
        kycRules.allow(testUser);
        kycRules.deny(testUser);
        
        vm.stopPrank();
        
        // Verify status
        assertFalse(kycRules.isAllowed(testUser));
        assertFalse(kycRules.isAddressAllowed(testUser));
        assertTrue(kycRules.isAddressDenied(testUser));
    }
    
    // Test reset functionality
    function test_Reset() public {
        // Setup
        address testUser = address(0x123);
        
        // Try removing restriction with non-authorized address
        vm.startPrank(alice);
        vm.expectRevert(); // Just expect any revert
        kycRules.reset(testUser);
        vm.stopPrank();
        
        // Test functionality
        vm.startPrank(owner);
        
        // Try with zero address
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.reset(address(0));
        
        // Setup initial state
        kycRules.allow(testUser);
        assertTrue(kycRules.isAllowed(testUser));
        
        // Reset address
        kycRules.reset(testUser);
        
        vm.stopPrank();
        
        // Verify status (should be back to default)
        assertFalse(kycRules.isAllowed(testUser));
        assertFalse(kycRules.isAddressAllowed(testUser));
        assertFalse(kycRules.isAddressDenied(testUser));
        
        // Also test with a denied address
        vm.startPrank(owner);
        kycRules.deny(alice);
        kycRules.reset(alice);
        vm.stopPrank();
        
        assertFalse(kycRules.isAddressDenied(alice));
    }
    
    // Test batch operations
    function test_BatchOperations() public {
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x1000);
        accounts[1] = address(0x2000);
        accounts[2] = address(0x3000);
        
        vm.startPrank(owner);
        
        // Test batch allow
        kycRules.batchAllow(accounts);
        
        // Verify all addresses were allowed
        for (uint256 i = 0; i < accounts.length; i++) {
            assertTrue(kycRules.isAddressAllowed(accounts[i]));
            assertTrue(kycRules.isAllowed(accounts[i]));
        }
        
        // Test batch deny
        kycRules.batchDeny(accounts);
        
        // Verify all addresses were denied
        for (uint256 i = 0; i < accounts.length; i++) {
            assertFalse(kycRules.isAddressAllowed(accounts[i]));
            assertTrue(kycRules.isAddressDenied(accounts[i]));
            assertFalse(kycRules.isAllowed(accounts[i]));
        }
        
        // Test batch reset
        kycRules.batchReset(accounts);
        
        // Verify all addresses were reset
        for (uint256 i = 0; i < accounts.length; i++) {
            assertFalse(kycRules.isAddressAllowed(accounts[i]));
            assertFalse(kycRules.isAddressDenied(accounts[i]));
            assertFalse(kycRules.isAllowed(accounts[i]));
        }
        
        vm.stopPrank();
    }
    
    // Test isAllowed functionality
    function test_IsAllowed() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRules.allow(alice);
        kycRules.deny(bob);
        vm.stopPrank();
        
        // Check behavior for all cases
        assertTrue(kycRules.isAllowed(alice)); // Explicitly allowed
        assertFalse(kycRules.isAllowed(bob)); // Explicitly denied
        assertFalse(kycRules.isAllowed(charlie)); // Default deny
        
        // Test blacklist supersedes whitelist case
        vm.startPrank(owner);
        // First add to whitelist
        kycRules.allow(charlie);
        assertTrue(kycRules.isAllowed(charlie)); // Now allowed
        
        // Then add to blacklist - this should take precedence
        kycRules.deny(charlie);
        assertFalse(kycRules.isAllowed(charlie)); // Should be denied even though previously allowed
        vm.stopPrank();
    }
    
    // Test evaluateTransfer with all possible KYC combinations
    function test_EvaluateTransfer_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRules.allow(alice);
        kycRules.allow(bob);
        kycRules.deny(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // Both allowed
        result = kycRules.evaluateTransfer(address(0), alice, bob, 100);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Sender denied
        result = kycRules.evaluateTransfer(address(0), charlie, bob, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Receiver denied
        result = kycRules.evaluateTransfer(address(0), alice, charlie, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Both denied
        result = kycRules.evaluateTransfer(address(0), charlie, charlie, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Default deny (unrestricted address)
        address unrestrictedUser = address(0x456);
        result = kycRules.evaluateTransfer(address(0), alice, unrestrictedUser, 100);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
    }
    
    // Test evaluateDeposit with all possible KYC combinations
    function test_EvaluateDeposit_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRules.allow(alice);
        kycRules.allow(bob);
        kycRules.deny(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // Both allowed
        result = kycRules.evaluateDeposit(address(0), alice, 100, bob);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Sender denied
        result = kycRules.evaluateDeposit(address(0), charlie, 100, bob);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Receiver denied
        result = kycRules.evaluateDeposit(address(0), alice, 100, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Both denied
        result = kycRules.evaluateDeposit(address(0), charlie, 100, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Default deny (unrestricted address)
        address unrestrictedUser = address(0x456);
        result = kycRules.evaluateDeposit(address(0), alice, 100, unrestrictedUser);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
    }
    
    // Test evaluateWithdraw with all possible KYC combinations
    function test_EvaluateWithdraw_Comprehensive() public {
        // Setup mixed state
        vm.startPrank(owner);
        kycRules.allow(alice);
        kycRules.allow(bob);
        kycRules.deny(charlie);
        vm.stopPrank();
        
        IRules.RuleResult memory result;
        
        // All addresses allowed
        result = kycRules.evaluateWithdraw(address(0), alice, 100, bob, alice);
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // User (initiator) denied
        result = kycRules.evaluateWithdraw(address(0), charlie, 100, bob, alice);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Owner denied
        result = kycRules.evaluateWithdraw(address(0), alice, 100, bob, charlie);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: owner");
        
        // Receiver denied
        result = kycRules.evaluateWithdraw(address(0), alice, 100, charlie, alice);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Default deny (unrestricted addresses)
        address unrestrictedUser = address(0x456);
        result = kycRules.evaluateWithdraw(address(0), alice, 100, bob, unrestrictedUser);
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: owner");
    }
    
    // Test invalid batch operations
    function test_InvalidBatchOperations() public {
        // Test empty array validation
        address[] memory emptyArray = new address[](0);
        
        vm.startPrank(owner);
        
        vm.expectRevert(KycRules.InvalidArrayLength.selector);
        kycRules.batchAllow(emptyArray);
        
        vm.expectRevert(KycRules.InvalidArrayLength.selector);
        kycRules.batchDeny(emptyArray);
        
        vm.expectRevert(KycRules.InvalidArrayLength.selector);
        kycRules.batchReset(emptyArray);
        
        // Test zero address validation in batch operations
        address[] memory accountsWithZero = new address[](3);
        accountsWithZero[0] = address(0x1000);
        accountsWithZero[1] = address(0); // Zero address
        accountsWithZero[2] = address(0x3000);
        
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.batchAllow(accountsWithZero);
        
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.batchDeny(accountsWithZero);
        
        vm.expectRevert(KycRules.ZeroAddress.selector);
        kycRules.batchReset(accountsWithZero);
        
        vm.stopPrank();
    }
    
    // Test batch allow with denied addresses
    function test_BatchAllowWithDeniedAddresses() public {
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x1000);
        accounts[1] = address(0x2000);
        accounts[2] = address(0x3000);
        
        vm.startPrank(owner);
        
        // Deny one address first
        kycRules.deny(accounts[1]);
        
        // Batch allow should revert when it encounters a denied address
        vm.expectRevert(KycRules.AddressAlreadyDenied.selector);
        kycRules.batchAllow(accounts);
        
        vm.stopPrank();
    }
}