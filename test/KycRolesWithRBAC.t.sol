// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {RoleManaged} from "../src/auth/RoleManaged.sol";
import {KycRules} from "../src/rules/KycRules.sol";

contract KycRolesWithRBACTest is Test {
    RoleManager public roleManager;
    KycRules public kycRules;
    
    address public admin = address(1);
    address public kycAdmin = address(2);
    address public kycOperator = address(3);
    address public user1 = address(4);
    address public user2 = address(5);
    
    function setUp() public {
        vm.startPrank(admin);
        roleManager = new RoleManager();
        kycRules = new KycRules(address(roleManager));
        
        // Set up roles
        roleManager.grantRole(kycAdmin, roleManager.KYC_ADMIN());
        vm.stopPrank();
        
        vm.startPrank(kycAdmin);
        roleManager.grantRole(kycOperator, roleManager.KYC_OPERATOR());
        vm.stopPrank();
    }
    
    // Test KYC admin role permissions
    function testKycAdminCanAllow() public {
        vm.startPrank(kycAdmin);
        kycRules.allow(user1);
        assertTrue(kycRules.isAllowed(user1));
        vm.stopPrank();
    }
    
    function testKycAdminCanDeny() public {
        vm.startPrank(kycAdmin);
        kycRules.deny(user1);
        assertFalse(kycRules.isAllowed(user1));
        vm.stopPrank();
    }
    
    function testKycAdminCanReset() public {
        vm.startPrank(kycAdmin);
        kycRules.allow(user1);
        assertTrue(kycRules.isAllowed(user1));
        kycRules.reset(user1);
        assertFalse(kycRules.isAllowed(user1));
        vm.stopPrank();
    }
    
    // Test KYC operator role permissions
    function testKycOperatorCanAllow() public {
        vm.startPrank(kycOperator);
        kycRules.allow(user1);
        assertTrue(kycRules.isAllowed(user1));
        vm.stopPrank();
    }
    
    function testKycOperatorCanDeny() public {
        vm.startPrank(kycOperator);
        kycRules.deny(user1);
        assertFalse(kycRules.isAllowed(user1));
        vm.stopPrank();
    }
    
    function testKycOperatorCannotReset() public {
        vm.startPrank(kycAdmin);
        kycRules.allow(user1);
        assertTrue(kycRules.isAllowed(user1));
        vm.stopPrank();
        
        vm.startPrank(kycOperator);
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.Unauthorized.selector, kycOperator, roleManager.KYC_ADMIN()));
        kycRules.reset(user1);
        vm.stopPrank();
    }
    
    // Test batch operations
    function testBatchAllow() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        vm.startPrank(kycAdmin);
        kycRules.batchAllow(users);
        vm.stopPrank();
        
        assertTrue(kycRules.isAllowed(user1));
        assertTrue(kycRules.isAllowed(user2));
    }
    
    function testBatchDeny() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        vm.startPrank(kycAdmin);
        kycRules.batchAllow(users);
        assertTrue(kycRules.isAllowed(user1));
        assertTrue(kycRules.isAllowed(user2));
        
        kycRules.batchDeny(users);
        vm.stopPrank();
        
        assertFalse(kycRules.isAllowed(user1));
        assertFalse(kycRules.isAllowed(user2));
    }
    
    function testBatchReset() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        vm.startPrank(kycAdmin);
        kycRules.batchDeny(users);
        assertFalse(kycRules.isAllowed(user1));
        assertFalse(kycRules.isAllowed(user2));
        
        kycRules.batchReset(users);
        vm.stopPrank();
        
        assertFalse(kycRules.isAllowed(user1));
        assertFalse(kycRules.isAllowed(user2));
        assertFalse(kycRules.isAddressDenied(user1));
        assertFalse(kycRules.isAddressDenied(user2));
    }
    
    // Test unauthorized access
    function testUnauthorizedAccess() public {
        vm.startPrank(user1);
        vm.expectRevert(); // We don't know exactly which role would be reported in the error
        kycRules.allow(user2);
        vm.stopPrank();
    }
}