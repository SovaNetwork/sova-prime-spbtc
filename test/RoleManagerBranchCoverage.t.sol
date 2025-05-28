// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title RoleManagerBranchCoverageTest
 * @notice Additional tests to achieve 100% branch coverage for RoleManager.sol
 */
contract RoleManagerBranchCoverageTest is Test {
    RoleManager public roleManager;
    
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    
    // Copy role constants from RoleManager
    uint256 internal constant FLAG_PROTOCOL_ADMIN = 1 << 0;
    uint256 internal constant FLAG_STRATEGY_ADMIN = 1 << 1;
    uint256 internal constant FLAG_RULES_ADMIN = 1 << 2;
    
    uint256 public constant STRATEGY_OPERATOR = 1 << 8;
    uint256 public constant KYC_OPERATOR = 1 << 9;
    
    uint256 public constant STRATEGY_ADMIN = FLAG_STRATEGY_ADMIN | STRATEGY_OPERATOR;
    uint256 public constant RULES_ADMIN = FLAG_RULES_ADMIN | KYC_OPERATOR;
    uint256 public constant PROTOCOL_ADMIN = FLAG_PROTOCOL_ADMIN | STRATEGY_ADMIN | RULES_ADMIN;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        
        roleManager = new RoleManager();
    }
    
    /**
     * @notice Test initializeRegistry when called by non-owner
     * @dev Covers branch: if (msg.sender != owner()) revert Unauthorized();
     */
    function test_InitializeRegistry_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.initializeRegistry(address(0x100));
    }
    
    /**
     * @notice Test initializeRegistry when already initialized
     * @dev Covers branch: if (registry != address(0)) revert AlreadyInitialized();
     */
    function test_InitializeRegistry_AlreadyInitialized() public {
        // First initialization should succeed
        roleManager.initializeRegistry(address(0x100));
        
        // Second initialization should fail
        vm.expectRevert(Ownable.AlreadyInitialized.selector);
        roleManager.initializeRegistry(address(0x200));
    }
    
    /**
     * @notice Test granting role 0
     * @dev Covers branch: if (role == 0) revert InvalidRole();
     */
    function test_GrantRole_ZeroRole() public {
        vm.expectRevert(RoleManager.InvalidRole.selector);
        roleManager.grantRole(alice, 0);
    }
    
    /**
     * @notice Test revoking role 0
     * @dev Covers branch: if (role == 0) revert InvalidRole();
     */
    function test_RevokeRole_ZeroRole() public {
        vm.expectRevert(RoleManager.InvalidRole.selector);
        roleManager.revokeRole(alice, 0);
    }
    
    /**
     * @notice Test PROTOCOL_ADMIN managing roles (not PROTOCOL_ADMIN itself)
     * @dev Covers branch: if (hasAllRoles(manager, PROTOCOL_ADMIN)) return role != PROTOCOL_ADMIN;
     */
    function test_ProtocolAdmin_CanManageOtherRoles() public {
        // Grant PROTOCOL_ADMIN to alice
        roleManager.grantRole(alice, PROTOCOL_ADMIN);
        
        // Alice (PROTOCOL_ADMIN) should be able to grant STRATEGY_ADMIN
        vm.prank(alice);
        roleManager.grantRole(bob, STRATEGY_ADMIN);
        assertTrue(roleManager.hasAllRoles(bob, STRATEGY_ADMIN));
        
        // Alice (PROTOCOL_ADMIN) should be able to grant KYC_OPERATOR
        vm.prank(alice);
        roleManager.grantRole(charlie, KYC_OPERATOR);
        assertTrue(roleManager.hasAllRoles(charlie, KYC_OPERATOR));
    }
    
    /**
     * @notice Test PROTOCOL_ADMIN cannot grant PROTOCOL_ADMIN role
     * @dev Covers branch: if (hasAllRoles(manager, PROTOCOL_ADMIN)) return role != PROTOCOL_ADMIN;
     */
    function test_ProtocolAdmin_CannotGrantProtocolAdmin() public {
        // Grant PROTOCOL_ADMIN to alice
        roleManager.grantRole(alice, PROTOCOL_ADMIN);
        
        // Alice (PROTOCOL_ADMIN) should NOT be able to grant PROTOCOL_ADMIN
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.grantRole(bob, PROTOCOL_ADMIN);
    }
    
    /**
     * @notice Test role management with explicit roleAdminRole mapping
     * @dev Covers branch: if (requiredAdminRole != 0) return hasAllRoles(manager, requiredAdminRole);
     */
    function test_RoleManagement_WithExplicitAdminRole() public {
        // Define a custom role and its admin
        uint256 CUSTOM_ROLE = 1 << 20;
        uint256 CUSTOM_ADMIN = 1 << 21;
        
        // Set CUSTOM_ADMIN as the admin for CUSTOM_ROLE
        roleManager.setRoleAdmin(CUSTOM_ROLE, CUSTOM_ADMIN);
        
        // Grant CUSTOM_ADMIN to alice
        roleManager.grantRole(alice, CUSTOM_ADMIN);
        
        // Alice should now be able to grant CUSTOM_ROLE
        vm.prank(alice);
        roleManager.grantRole(bob, CUSTOM_ROLE);
        assertTrue(roleManager.hasAllRoles(bob, CUSTOM_ROLE));
        
        // Charlie (without CUSTOM_ADMIN) should NOT be able to grant CUSTOM_ROLE
        vm.prank(charlie);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.grantRole(bob, CUSTOM_ROLE);
    }
    
    /**
     * @notice Test setRoleAdmin when called by non-owner and non-PROTOCOL_ADMIN
     * @dev Covers branch: if (msg.sender != owner() && !hasAllRoles(msg.sender, PROTOCOL_ADMIN))
     */
    function test_SetRoleAdmin_Unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.setRoleAdmin(STRATEGY_OPERATOR, STRATEGY_ADMIN);
    }
    
    /**
     * @notice Test setRoleAdmin when called by PROTOCOL_ADMIN (not owner)
     * @dev Covers branch: if (msg.sender != owner() && !hasAllRoles(msg.sender, PROTOCOL_ADMIN))
     */
    function test_SetRoleAdmin_ByProtocolAdmin() public {
        // Grant PROTOCOL_ADMIN to alice
        roleManager.grantRole(alice, PROTOCOL_ADMIN);
        
        // Alice (PROTOCOL_ADMIN) should be able to set role admin
        uint256 CUSTOM_ROLE = 1 << 20;
        uint256 CUSTOM_ADMIN = 1 << 21;
        
        vm.prank(alice);
        roleManager.setRoleAdmin(CUSTOM_ROLE, CUSTOM_ADMIN);
        
        assertEq(roleManager.roleAdminRole(CUSTOM_ROLE), CUSTOM_ADMIN);
    }
    
    /**
     * @notice Test setRoleAdmin with targetRole = 0
     * @dev Covers branch: if (targetRole == 0 || targetRole == PROTOCOL_ADMIN) revert InvalidRole();
     */
    function test_SetRoleAdmin_ZeroTargetRole() public {
        vm.expectRevert(RoleManager.InvalidRole.selector);
        roleManager.setRoleAdmin(0, STRATEGY_ADMIN);
    }
    
    /**
     * @notice Test setRoleAdmin with targetRole = PROTOCOL_ADMIN
     * @dev Covers branch: if (targetRole == 0 || targetRole == PROTOCOL_ADMIN) revert InvalidRole();
     */
    function test_SetRoleAdmin_ProtocolAdminTargetRole() public {
        vm.expectRevert(RoleManager.InvalidRole.selector);
        roleManager.setRoleAdmin(PROTOCOL_ADMIN, STRATEGY_ADMIN);
    }
    
    /**
     * @notice Test setting roleAdminRole to 0 (requiring owner/PROTOCOL_ADMIN)
     * @dev Covers the case where roleAdminRole is explicitly set to 0
     */
    function test_SetRoleAdmin_ToZero() public {
        uint256 CUSTOM_ROLE = 1 << 20;
        
        // First set a non-zero admin
        roleManager.setRoleAdmin(CUSTOM_ROLE, STRATEGY_ADMIN);
        
        // Then set it back to 0
        roleManager.setRoleAdmin(CUSTOM_ROLE, 0);
        
        // Now only owner or PROTOCOL_ADMIN should be able to manage CUSTOM_ROLE
        // Regular user cannot grant it
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.grantRole(bob, CUSTOM_ROLE);
        
        // But owner can
        roleManager.grantRole(bob, CUSTOM_ROLE);
        assertTrue(roleManager.hasAllRoles(bob, CUSTOM_ROLE));
    }
    
    /**
     * @notice Test role management when roleAdminRole returns 0 (default)
     * @dev Covers the final return false in _canManageRole
     */
    function test_RoleManagement_NoAdminRoleSet() public {
        // Create a custom role that has no admin set
        uint256 CUSTOM_ROLE = 1 << 25;
        
        // Regular user cannot grant this role
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        roleManager.grantRole(bob, CUSTOM_ROLE);
        
        // But owner can
        roleManager.grantRole(bob, CUSTOM_ROLE);
        assertTrue(roleManager.hasAllRoles(bob, CUSTOM_ROLE));
    }
}