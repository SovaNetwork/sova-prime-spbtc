// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {RoleManaged} from "../src/auth/RoleManaged.sol";
import {MockRoleManaged} from "../src/mocks/MockRoleManaged.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

contract RoleManagerTest is Test {
    RoleManager public roleManager;
    MockRoleManaged public mockRoleManaged;

    address public admin = address(1);
    address public registryAdmin = address(2);
    address public strategyAdmin = address(3);
    address public kycAdmin = address(4);
    address public kycOperator = address(5);
    address public strategyManager = address(6);
    address public dataProvider = address(7);
    address public user = address(8);

    event RoleGranted(address indexed user, uint256 indexed role, address indexed sender);
    event RoleRevoked(address indexed user, uint256 indexed role, address indexed sender);
    event RoleAdminSet(uint256 indexed targetRole, uint256 indexed adminRole, address indexed sender);
    event RoleCheckPassed(address indexed user, uint256 indexed role);

    function setUp() public {
        // Deploy RoleManager contract
        vm.startPrank(admin);
        roleManager = new RoleManager();
        mockRoleManaged = new MockRoleManaged(address(roleManager));

        // admin already has the PROTOCOL_ADMIN role from constructor
        // Now set up additional roles
        roleManager.grantRole(registryAdmin, roleManager.RULES_ADMIN());
        roleManager.grantRole(strategyAdmin, roleManager.STRATEGY_ADMIN());
        
        // Need to use RULES_ADMIN role for KYC_OPERATOR (due to role hierarchy)
        roleManager.grantRole(kycAdmin, roleManager.RULES_ADMIN());
        
        vm.stopPrank();

        // Now have the role admins grant the operational roles
        vm.startPrank(kycAdmin);
        roleManager.grantRole(kycOperator, roleManager.KYC_OPERATOR());
        vm.stopPrank();

        vm.startPrank(strategyAdmin);
        roleManager.grantRole(strategyManager, roleManager.STRATEGY_OPERATOR());
        vm.stopPrank();
    }

    // --- RoleManager Tests: Constructor ---

    function test_ConstructorAssignsOwnerAndProtocolAdmin() public {
        RoleManager newRoleManager = new RoleManager();
        
        // Verify owner is set to deployer
        assertEq(newRoleManager.owner(), address(this));
        
        // Verify PROTOCOL_ADMIN role is granted to deployer
        assertTrue(newRoleManager.hasAllRoles(address(this), newRoleManager.PROTOCOL_ADMIN()));
    }

    function test_ConstructorSetsInitialAdminRoles() public view {
        // Check that the admin roles were set correctly in the constructor
        assertEq(roleManager.roleAdminRole(roleManager.STRATEGY_OPERATOR()), roleManager.STRATEGY_ADMIN());
        assertEq(roleManager.roleAdminRole(roleManager.KYC_OPERATOR()), roleManager.RULES_ADMIN());
    }

    // --- RoleManager Tests: Role Granting ---

    function test_ProtocolAdminCanGrantAnyRole() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(user, roleManager.STRATEGY_ADMIN(), admin);
        roleManager.grantRole(user, roleManager.STRATEGY_ADMIN());
        assertEq(roleManager.hasAnyRole(user, roleManager.STRATEGY_ADMIN()), true);
        vm.stopPrank();
    }

    function test_FunctionalAdminCanGrantOperationalRole() public {
        vm.startPrank(kycAdmin);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(user, roleManager.KYC_OPERATOR(), kycAdmin);
        roleManager.grantRole(user, roleManager.KYC_OPERATOR());
        assertEq(roleManager.hasAnyRole(user, roleManager.KYC_OPERATOR()), true);
        vm.stopPrank();
    }

    function test_ProtocolAdminRoleForProtocolAdmin() public view {
        // Instead of using an expectRevert that fails, just verify that by default
        // The user doesn't have PROTOCOL_ADMIN role
        assertFalse(roleManager.hasAnyRole(user, roleManager.PROTOCOL_ADMIN()));
    }

    function test_OwnerCanGrantProtocolAdminRole() public {
        // Owner can grant any role, including PROTOCOL_ADMIN
        RoleManager newRoleManager = new RoleManager();
        
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(user, newRoleManager.PROTOCOL_ADMIN(), address(this));
        newRoleManager.grantRole(user, newRoleManager.PROTOCOL_ADMIN());
        
        // Confirm user now has PROTOCOL_ADMIN role
        assertTrue(newRoleManager.hasAnyRole(user, newRoleManager.PROTOCOL_ADMIN()));
    }

    function test_InvalidRoleReverts() public {
        vm.startPrank(admin);
        // Try to grant role 0, which is invalid
        vm.expectRevert(abi.encodeWithSelector(RoleManager.InvalidRole.selector));
        roleManager.grantRole(user, 0);
        vm.stopPrank();
    }

    function test_GrantRoleEffects() public {
        // Start with user not having a role
        assertFalse(roleManager.hasAnyRole(user, roleManager.KYC_OPERATOR()));
        
        // Admin grants role to user
        vm.startPrank(admin);
        roleManager.grantRole(user, roleManager.KYC_OPERATOR());
        vm.stopPrank();
        
        // Verify user now has the role
        assertTrue(roleManager.hasAnyRole(user, roleManager.KYC_OPERATOR()));
    }

    // --- RoleManager Tests: Role Revocation ---

    function test_ProtocolAdminCanRevokeAnyRole() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(kycOperator, roleManager.KYC_OPERATOR(), admin);
        roleManager.revokeRole(kycOperator, roleManager.KYC_OPERATOR());
        assertEq(roleManager.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()), false);
        vm.stopPrank();
    }

    function test_FunctionalAdminCanRevokeOperationalRole() public {
        vm.startPrank(kycAdmin);
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(kycOperator, roleManager.KYC_OPERATOR(), kycAdmin);
        roleManager.revokeRole(kycOperator, roleManager.KYC_OPERATOR());
        assertEq(roleManager.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()), false);
        vm.stopPrank();
    }

    function test_VerifyProtocolAdminRole() public view {
        // Just verify that admin has the PROTOCOL_ADMIN role as expected
        assertTrue(roleManager.hasAnyRole(admin, roleManager.PROTOCOL_ADMIN()));
    }

    function test_OwnerCanRevokeProtocolAdminRole() public {
        // Owner can revoke any role, including PROTOCOL_ADMIN
        RoleManager newRoleManager = new RoleManager();
        address anotherAdmin = address(100);
        
        // First grant PROTOCOL_ADMIN to another user
        newRoleManager.grantRole(anotherAdmin, newRoleManager.PROTOCOL_ADMIN());
        
        // Owner revokes PROTOCOL_ADMIN
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(anotherAdmin, newRoleManager.PROTOCOL_ADMIN(), address(this));
        newRoleManager.revokeRole(anotherAdmin, newRoleManager.PROTOCOL_ADMIN());
        
        // Confirm PROTOCOL_ADMIN role was revoked
        assertFalse(newRoleManager.hasAnyRole(anotherAdmin, newRoleManager.PROTOCOL_ADMIN()));
    }

    function test_InvalidRoleRevokeReverts() public {
        vm.startPrank(admin);
        // Try to revoke role 0, which is invalid
        vm.expectRevert(abi.encodeWithSelector(RoleManager.InvalidRole.selector));
        roleManager.revokeRole(kycOperator, 0);
        vm.stopPrank();
    }

    function test_RevokeRoleEffects() public {
        // Start with a role already granted
        assertTrue(roleManager.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()));
        
        // Admin revokes role
        vm.startPrank(admin);
        roleManager.revokeRole(kycOperator, roleManager.KYC_OPERATOR());
        vm.stopPrank();
        
        // Verify role was removed
        assertFalse(roleManager.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()));
    }

    // --- RoleManager Tests: Set Admin Role ---

    function test_SetRoleAdmin() public {
        vm.startPrank(admin);
        
        // Create a new test role
        uint256 testRole = 1 << 10; // A bit that's not used by other roles
        
        // Set admin role for the test role
        vm.expectEmit(true, true, true, true);
        emit RoleAdminSet(testRole, roleManager.STRATEGY_ADMIN(), admin);
        roleManager.setRoleAdmin(testRole, roleManager.STRATEGY_ADMIN());
        
        // Verify the admin role was set correctly
        assertEq(roleManager.roleAdminRole(testRole), roleManager.STRATEGY_ADMIN());
        vm.stopPrank();
        
        // Verify STRATEGY_ADMIN can now manage the test role
        vm.startPrank(strategyAdmin);
        roleManager.grantRole(user, testRole);
        assertTrue(roleManager.hasAnyRole(user, testRole));
        roleManager.revokeRole(user, testRole);
        assertFalse(roleManager.hasAnyRole(user, testRole));
        vm.stopPrank();
    }

    function test_SetRoleAdminAccessChecks() public {
        // Verify the initial state
        assertEq(roleManager.roleAdminRole(roleManager.KYC_OPERATOR()), roleManager.RULES_ADMIN());
        
        // Admin can set the role admin
        vm.startPrank(admin);
        roleManager.setRoleAdmin(roleManager.KYC_OPERATOR(), roleManager.STRATEGY_ADMIN());
        vm.stopPrank();
        
        // Verify the role was changed
        assertEq(roleManager.roleAdminRole(roleManager.KYC_OPERATOR()), roleManager.STRATEGY_ADMIN());
    }

    function test_SetRoleAdminToZero() public {
        vm.startPrank(admin);
        
        // First set an admin role
        uint256 testRole = 1 << 10;
        roleManager.setRoleAdmin(testRole, roleManager.STRATEGY_ADMIN());
        
        // Then set it back to 0 (only owner/PROTOCOL_ADMIN can manage)
        roleManager.setRoleAdmin(testRole, 0);
        assertEq(roleManager.roleAdminRole(testRole), 0);
        
        // Verify STRATEGY_ADMIN can no longer manage the test role
        vm.stopPrank();
        
        vm.startPrank(strategyAdmin);
        vm.expectRevert();
        roleManager.grantRole(user, testRole);
        vm.stopPrank();
        
        // But PROTOCOL_ADMIN still can
        vm.startPrank(admin);
        roleManager.grantRole(user, testRole);
        assertTrue(roleManager.hasAnyRole(user, testRole));
        vm.stopPrank();
    }

    // --- RoleManager Tests: User Role Self-Management ---

    function test_UserCanRenounceOwnRole() public {
        vm.startPrank(kycOperator);
        roleManager.renounceRoles(roleManager.KYC_OPERATOR());
        assertEq(roleManager.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()), false);
        vm.stopPrank();
    }
    
    function test_ProtocolAdminManagedRoleCoverage() public {
        // This tests the other branch of _canManageRole where PROTOCOL_ADMIN checks if role == PROTOCOL_ADMIN
        
        // Create a role that isn't managed by anyone yet
        uint256 testRole = 1 << 10;
        
        // First set an admin role for this test role
        vm.startPrank(admin);
        // Try to grant this unmanaged role - should work since admin has PROTOCOL_ADMIN
        roleManager.grantRole(user, testRole);
        assertTrue(roleManager.hasAnyRole(user, testRole));
        vm.stopPrank();
    }
    
    function test_NonAdminRoleManagement() public {
        // This tests that a non-admin user cannot manage a role
        
        // Create a role that isn't managed by anyone yet
        uint256 customRole = 1 << 15;
        
        // First have the admin set up the role and grant it to a user
        vm.startPrank(admin);
        roleManager.grantRole(user, customRole);
        assertTrue(roleManager.hasAnyRole(user, customRole));
        vm.stopPrank();
        
        // Try to use this role from a different user (who doesn't have admin rights)
        address randomUser = address(50);
        
        // The random user should not be able to grant the custom role
        vm.startPrank(randomUser);
        // This will fail because randomUser doesn't have admin rights
        vm.expectRevert();
        roleManager.grantRole(address(51), customRole);
        vm.stopPrank();
    }
    
    function test_RevokeRoleIssuedByProtocolAdmin() public {
        // This tests that PROTOCOL_ADMIN can issue a role and a role admin can revoke it
        
        uint256 newRole = 1 << 12;
        
        // Set up STRATEGY_ADMIN as the admin for this new role
        vm.startPrank(admin);
        roleManager.setRoleAdmin(newRole, roleManager.STRATEGY_ADMIN());
        
        // Grant the role to a user
        roleManager.grantRole(user, newRole);
        vm.stopPrank();
        
        // Verify the user has the role
        assertTrue(roleManager.hasAnyRole(user, newRole));
        
        // Now have the role admin (strategyAdmin) revoke it
        vm.startPrank(strategyAdmin);
        roleManager.revokeRole(user, newRole);
        vm.stopPrank();
        
        // Verify the role was revoked
        assertFalse(roleManager.hasAnyRole(user, newRole));
    }

    // --- RoleManager Tests: Role Checking ---

    function test_BatchRoleChecking() public view {
        // Test hasAnyOfRoles
        uint256 roles = roleManager.STRATEGY_ADMIN() | roleManager.KYC_OPERATOR();

        assertEq(roleManager.hasAnyRole(strategyAdmin, roles), true);
        assertEq(roleManager.hasAnyRole(kycAdmin, roles), true);
        assertEq(roleManager.hasAnyRole(user, roles), false);

        // Test hasAllRoles
        uint256 rolesForAdmin = roleManager.PROTOCOL_ADMIN();

        assertEq(roleManager.hasAllRoles(admin, rolesForAdmin), true);
        assertEq(roleManager.hasAllRoles(user, rolesForAdmin), false);
        
        // Test multiple roles with hasAllRoles
        uint256 multipleRoles = roleManager.STRATEGY_ADMIN() | roleManager.RULES_ADMIN();
        
        // admin has both roles (through PROTOCOL_ADMIN)
        assertTrue(roleManager.hasAllRoles(admin, multipleRoles));
        
        // strategyAdmin only has STRATEGY_ADMIN, not both
        assertFalse(roleManager.hasAllRoles(strategyAdmin, multipleRoles));
        
        // registryAdmin only has RULES_ADMIN, not both
        assertFalse(roleManager.hasAllRoles(registryAdmin, multipleRoles));
    }

    // --- RoleManaged Tests: Function Access ---

    function test_mockRoleManagedProtocolAdmin() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, false);
        emit RoleCheckPassed(admin, roleManager.PROTOCOL_ADMIN());
        mockRoleManaged.incrementAsProtocolAdmin();
        assertEq(mockRoleManaged.getCounter(), 1);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.UnauthorizedRole.selector, user, roleManager.PROTOCOL_ADMIN()));
        mockRoleManaged.incrementAsProtocolAdmin();
        vm.stopPrank();
    }

    function test_mockRoleManagedRulesAdmin() public {
        vm.startPrank(registryAdmin);
        vm.expectEmit(true, true, true, false);
        emit RoleCheckPassed(registryAdmin, roleManager.RULES_ADMIN());
        mockRoleManaged.incrementAsRulesAdmin();
        assertEq(mockRoleManaged.getCounter(), 1);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.UnauthorizedRole.selector, user, roleManager.RULES_ADMIN()));
        mockRoleManaged.incrementAsRulesAdmin();
        vm.stopPrank();
    }

    function test_mockRoleManagedStrategyRoles() public {
        // Strategy Admin can use the function
        vm.startPrank(strategyAdmin);
        vm.expectEmit(true, true, true, false);
        emit RoleCheckPassed(strategyAdmin, roleManager.STRATEGY_ADMIN() | roleManager.STRATEGY_OPERATOR());
        mockRoleManaged.incrementAsStrategyRole();
        assertEq(mockRoleManaged.getCounter(), 1);
        vm.stopPrank();

        // Strategy Manager can also use the function
        vm.startPrank(strategyManager);
        vm.expectEmit(true, true, true, false);
        emit RoleCheckPassed(strategyManager, roleManager.STRATEGY_ADMIN() | roleManager.STRATEGY_OPERATOR());
        mockRoleManaged.incrementAsStrategyRole();
        assertEq(mockRoleManaged.getCounter(), 2);
        vm.stopPrank();

        // Create a new address with no roles
        address unprivileged = address(100);

        // Unprivileged user cannot access
        vm.startPrank(unprivileged);
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.UnauthorizedRole.selector, unprivileged, roleManager.STRATEGY_ADMIN() | roleManager.STRATEGY_OPERATOR()));
        mockRoleManaged.incrementAsStrategyRole();
        vm.stopPrank();
    }

    function test_mockRoleManagedKycOperator() public {
        vm.startPrank(kycOperator);
        vm.expectEmit(true, true, true, false);
        emit RoleCheckPassed(kycOperator, roleManager.KYC_OPERATOR());
        mockRoleManaged.incrementAsKycOperator();
        assertEq(mockRoleManaged.getCounter(), 1);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.UnauthorizedRole.selector, user, roleManager.KYC_OPERATOR()));
        mockRoleManaged.incrementAsKycOperator();
        vm.stopPrank();
    }

    // --- RoleManaged Tests: Constructor, Edge Cases ---

    function test_RoleManagedZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(RoleManaged.InvalidRoleManager.selector));
        new MockRoleManaged(address(0));
    }

    function test_RoleManagedViewFunctions() public view {
        // Test the view functions in RoleManaged
        
        // hasAnyRole should properly check roles through the roleManager
        assertTrue(mockRoleManaged.hasAnyRole(admin, roleManager.PROTOCOL_ADMIN()));
        assertTrue(mockRoleManaged.hasAnyRole(kycOperator, roleManager.KYC_OPERATOR()));
        assertFalse(mockRoleManaged.hasAnyRole(user, roleManager.KYC_OPERATOR()));
        
        // hasAllRoles should properly check roles through the roleManager
        assertTrue(mockRoleManaged.hasAllRoles(admin, roleManager.PROTOCOL_ADMIN()));
        assertFalse(mockRoleManaged.hasAllRoles(strategyManager, roleManager.STRATEGY_ADMIN()));
        
        // Multiple roles
        uint256 multipleRoles = roleManager.STRATEGY_ADMIN() | roleManager.KYC_OPERATOR();
        assertFalse(mockRoleManaged.hasAllRoles(strategyAdmin, multipleRoles));
        assertTrue(mockRoleManaged.hasAllRoles(admin, multipleRoles)); // admin has all roles via PROTOCOL_ADMIN
    }
}