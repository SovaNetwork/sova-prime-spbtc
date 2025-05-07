// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {KycRulesHook} from "../src/hooks/KycRulesHook.sol";
import {IHook} from "../src/hooks/IHook.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";

/**
 * @title KycRulesTest
 * @notice Test suite for KycRulesHook contract with 100% coverage target
 */
contract KycRulesTest is BaseFountfiTest {
    KycRulesHook public kycRules;
    MockRoleManager public mockRoleManager;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy mock role manager
        mockRoleManager = new MockRoleManager(owner);
        
        // Deploy KYC rules with mock role manager
        kycRules = new KycRulesHook(address(mockRoleManager));
        
        // Grant owner the KYC_OPERATOR role
        mockRoleManager.grantRole(owner, mockRoleManager.KYC_OPERATOR());
        
        vm.stopPrank();
    }
    
    function test_Constructor() public {
        // Verify constructor arguments
        assertEq(address(kycRules.roleManager()), address(mockRoleManager));
    }
    
    function test_Allow() public {
        vm.startPrank(owner);
        
        // Initial state
        assertFalse(kycRules.isAllowed(alice));
        
        // Allow alice
        kycRules.allow(alice);
        
        // Verify alice is allowed
        assertTrue(kycRules.isAllowed(alice));
        
        vm.stopPrank();
    }
    
    function test_Deny() public {
        vm.startPrank(owner);
        
        // Initial state
        assertFalse(kycRules.isAllowed(alice));
        
        // Allow alice first
        kycRules.allow(alice);
        assertTrue(kycRules.isAllowed(alice));
        
        // Deny alice
        kycRules.deny(alice);
        
        // Verify alice is denied
        assertFalse(kycRules.isAllowed(alice));
        
        vm.stopPrank();
    }
    
    function test_Reset() public {
        vm.startPrank(owner);
        
        // Initial state
        assertFalse(kycRules.isAllowed(alice));
        
        // Allow alice first
        kycRules.allow(alice);
        assertTrue(kycRules.isAllowed(alice));
        
        // Reset alice
        kycRules.reset(alice);
        
        // Verify alice is reset to denied
        assertFalse(kycRules.isAllowed(alice));
        
        vm.stopPrank();
    }
    
    function test_ZeroAddressRevert() public {
        vm.startPrank(owner);
        
        // Test allow with zero address
        vm.expectRevert(KycRulesHook.ZeroAddress.selector);
        kycRules.allow(address(0));
        
        // Test deny with zero address
        vm.expectRevert(KycRulesHook.ZeroAddress.selector);
        kycRules.deny(address(0));
        
        // Test reset with zero address
        vm.expectRevert(KycRulesHook.ZeroAddress.selector);
        kycRules.reset(address(0));
        
        vm.stopPrank();
    }
    
    function test_AlreadyDeniedRevert() public {
        vm.startPrank(owner);
        
        // Deny alice first
        kycRules.deny(alice);
        
        // Test allow on already denied address
        vm.expectRevert(KycRulesHook.AddressAlreadyDenied.selector);
        kycRules.allow(alice);
        
        vm.stopPrank();
    }
    
    function test_BatchOperations() public {
        vm.startPrank(owner);
        
        // Setup batch of addresses
        address[] memory addresses = new address[](3);
        addresses[0] = alice;
        addresses[1] = bob;
        addresses[2] = charlie;
        
        // Test batch allow
        kycRules.batchAllow(addresses);
        
        // Verify all addresses are allowed
        assertTrue(kycRules.isAllowed(alice));
        assertTrue(kycRules.isAllowed(bob));
        assertTrue(kycRules.isAllowed(charlie));
        
        // Test batch deny
        kycRules.batchDeny(addresses);
        
        // Verify all addresses are denied
        assertFalse(kycRules.isAllowed(alice));
        assertFalse(kycRules.isAllowed(bob));
        assertFalse(kycRules.isAllowed(charlie));
        
        // Test batch reset
        kycRules.batchReset(addresses);
        
        // Verify all addresses are reset
        assertFalse(kycRules.isAllowed(alice));
        assertFalse(kycRules.isAllowed(bob));
        assertFalse(kycRules.isAllowed(charlie));
        assertFalse(kycRules.isAddressDenied(alice));
        assertFalse(kycRules.isAddressDenied(bob));
        assertFalse(kycRules.isAddressDenied(charlie));
        
        vm.stopPrank();
    }
    
    function test_EmptyBatchRevert() public {
        vm.startPrank(owner);
        
        // Create empty array
        address[] memory emptyAddresses = new address[](0);
        
        // Test batch allow with empty array
        vm.expectRevert(KycRulesHook.InvalidArrayLength.selector);
        kycRules.batchAllow(emptyAddresses);
        
        // Test batch deny with empty array
        vm.expectRevert(KycRulesHook.InvalidArrayLength.selector);
        kycRules.batchDeny(emptyAddresses);
        
        // Test batch reset with empty array
        vm.expectRevert(KycRulesHook.InvalidArrayLength.selector);
        kycRules.batchReset(emptyAddresses);
        
        vm.stopPrank();
    }
    
    function test_OnBeforeTransfer() public {
        vm.startPrank(owner);
        
        // Allow alice and bob
        kycRules.allow(alice);
        kycRules.allow(bob);
        
        // Test transfer between allowed addresses
        IHook.HookOutput memory result = kycRules.onBeforeTransfer(
            address(0), alice, bob, 100
        );
        
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Test transfer from denied to allowed
        result = kycRules.onBeforeTransfer(
            address(0), charlie, alice, 100
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Test transfer from allowed to denied
        result = kycRules.onBeforeTransfer(
            address(0), alice, charlie, 100
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        vm.stopPrank();
    }
    
    function test_OnBeforeDeposit() public {
        vm.startPrank(owner);
        
        // Allow alice
        kycRules.allow(alice);
        
        // Test deposit with allowed user and receiver
        IHook.HookOutput memory result = kycRules.onBeforeDeposit(
            address(0), alice, 100, alice
        );
        
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Test deposit with denied user
        result = kycRules.onBeforeDeposit(
            address(0), charlie, 100, charlie
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Test deposit with denied receiver
        result = kycRules.onBeforeDeposit(
            address(0), alice, 100, charlie
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        vm.stopPrank();
    }
    
    function test_OnBeforeWithdraw() public {
        vm.startPrank(owner);
        
        // Allow alice and bob
        kycRules.allow(alice);
        kycRules.allow(bob);
        
        // Test withdraw with all addresses allowed
        IHook.HookOutput memory result = kycRules.onBeforeWithdraw(
            address(0), alice, 100, bob, alice
        );
        
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Test withdraw with denied user
        result = kycRules.onBeforeWithdraw(
            address(0), charlie, 100, bob, alice
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: sender");
        
        // Test withdraw with denied receiver
        result = kycRules.onBeforeWithdraw(
            address(0), alice, 100, charlie, alice
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: receiver");
        
        // Test withdraw with denied owner
        result = kycRules.onBeforeWithdraw(
            address(0), alice, 100, bob, charlie
        );
        
        assertFalse(result.approved);
        assertEq(result.reason, "KycRules: owner");
        
        vm.stopPrank();
    }
    
    function test_UnauthorizedOperation() public {
        vm.startPrank(alice); // alice is not an operator
        
        // Test unauthorized allow
        vm.expectRevert();
        kycRules.allow(bob);
        
        // Test unauthorized deny
        vm.expectRevert();
        kycRules.deny(bob);
        
        // Test unauthorized reset
        vm.expectRevert();
        kycRules.reset(bob);
        
        // Test unauthorized batch operations
        address[] memory addresses = new address[](1);
        addresses[0] = bob;
        
        vm.expectRevert();
        kycRules.batchAllow(addresses);
        
        vm.expectRevert();
        kycRules.batchDeny(addresses);
        
        vm.expectRevert();
        kycRules.batchReset(addresses);
        
        vm.stopPrank();
    }
}