// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title RoleManager
/// @notice Central role management contract for the Fountfi protocol
/// @dev Based on Solady's OwnableRoles implementation
contract RoleManager is OwnableRoles {
    // Role privilege levels
    uint256 private constant LEVEL_ROOT = 0xF00000; // Level 15 (highest)
    uint256 private constant LEVEL_ADMIN = 0xA00000; // Level 10
    uint256 private constant LEVEL_OPERATOR = 0x500000; // Level 5

    // Function domains (bits 8-15)
    uint256 public constant DOMAIN_PROTOCOL = 0x0100; // Domain 1
    uint256 public constant DOMAIN_STRATEGY = 0x0200; // Domain 2
    uint256 public constant DOMAIN_KYC = 0x0300; // Domain 3
    uint256 public constant DOMAIN_REPORTER = 0x0400; // Domain 4
    uint256 public constant DOMAIN_SUBSCRIPTION = 0x0500; // Domain 5
    uint256 public constant DOMAIN_WITHDRAWAL = 0x0600; // Domain 6
    uint256 public constant DOMAIN_RULES = 0x0700; // Domain 7

    // Base role identifiers (bits 0-7)
    uint256 private constant ID_ADMIN = 0x01;
    uint256 private constant ID_OPERATOR = 0x02;

    // Root role
    uint256 public constant PROTOCOL_ADMIN = LEVEL_ROOT | DOMAIN_PROTOCOL | ID_ADMIN;

    // Functional admin roles
    uint256 public constant STRATEGY_ADMIN = LEVEL_ADMIN | DOMAIN_STRATEGY | ID_ADMIN;
    uint256 public constant KYC_ADMIN = LEVEL_ADMIN | DOMAIN_KYC | ID_ADMIN;
    uint256 public constant REPORTER_ADMIN = LEVEL_ADMIN | DOMAIN_REPORTER | ID_ADMIN;
    uint256 public constant SUBSCRIPTION_ADMIN = LEVEL_ADMIN | DOMAIN_SUBSCRIPTION | ID_ADMIN;
    uint256 public constant WITHDRAWAL_ADMIN = LEVEL_ADMIN | DOMAIN_WITHDRAWAL | ID_ADMIN;
    uint256 public constant RULES_ADMIN = LEVEL_ADMIN | DOMAIN_RULES | ID_ADMIN;

    // Operational roles
    uint256 public constant STRATEGY_MANAGER = LEVEL_OPERATOR | DOMAIN_STRATEGY | ID_MANAGER;
    uint256 public constant KYC_OPERATOR = LEVEL_OPERATOR | DOMAIN_KYC | ID_OPERATOR;
    uint256 public constant DATA_PROVIDER = LEVEL_OPERATOR | DOMAIN_REPORTER | ID_OPERATOR;

    // Custom errors
    error InvalidRole();

    /// @notice Emitted when a role is granted to a user
    /// @param user The address of the user
    /// @param role The role that was granted
    /// @param sender The address that granted the role
    event RoleGranted(address indexed user, uint256 indexed role, address indexed sender);

    /// @notice Emitted when a role is revoked from a user
    /// @param user The address of the user
    /// @param role The role that was revoked
    /// @param sender The address that revoked the role
    event RoleRevoked(address indexed user, uint256 indexed role, address indexed sender);

    /// @notice Constructor that sets up the initial roles
    /// @dev Initializes the owner and grants PROTOCOL_ADMIN role to the deployer
    constructor() {
        if (msg.sender == address(0)) revert InvalidRole();

        _initializeOwner(msg.sender);
        // Grant PROTOCOL_ADMIN to deployer
        _grantRoles(msg.sender, PROTOCOL_ADMIN);

        // Emit event for easier off-chain tracking
        emit RoleGranted(msg.sender, PROTOCOL_ADMIN, address(0));
    }

    /// @notice Grants a role to a user
    /// @param user The address of the user to grant the role to
    /// @param role The role to grant
    function grantRole(address user, uint256 role) public payable virtual {
        // Check if authorized to grant this role
        _validateRoleGrant(role);

        // Grant the role
        _grantRoles(user, role);

        // Emit event
        emit RoleGranted(user, role, msg.sender);
    }

    /// @notice Revokes a role from a user
    /// @param user The address of the user to revoke the role from
    /// @param role The role to revoke
    function revokeRole(address user, uint256 role) public payable virtual {
        // Check if authorized to revoke this role
        _validateRoleRevoke(role);

        // Revoke the role
        _removeRoles(user, role);

        // Emit event
        emit RoleRevoked(user, role, msg.sender);
    }

    /// @notice Allows a user to renounce their own role
    /// @param role The role to renounce
    function renounceRole(uint256 role) public payable virtual {
        _removeRoles(msg.sender, role);

        // Emit event
        emit RoleRevoked(msg.sender, role, msg.sender);
    }

    /// @notice Checks if a user has a specific role
    /// @param user The address of the user to check
    /// @param role The role to check for
    /// @return True if the user has the role, false otherwise
    function hasRole(address user, uint256 role) public view virtual returns (bool) {
        return hasAnyRole(user, role);
    }

    /// @notice Batch checking if a user has any of the specified roles
    /// @param user The address of the user to check
    /// @param roles An array of roles to check for
    /// @return True if the user has any of the roles, false otherwise
    function hasAnyOfRoles(address user, uint256[] calldata roles) public view virtual returns (bool) {
        for (uint256 i = 0; i < roles.length; i++) {
            if (hasAnyRole(user, roles[i])) {
                return true;
            }
        }
        return false;
    }

    /// @notice Batch checking if a user has all of the specified roles
    /// @param user The address of the user to check
    /// @param roles An array of roles to check for
    /// @return True if the user has all of the roles, false otherwise
    function hasAllRoles(address user, uint256[] calldata roles) public view virtual returns (bool) {
        for (uint256 i = 0; i < roles.length; i++) {
            if (!hasAnyRole(user, roles[i])) {
                return false;
            }
        }
        return true;
    }

    /// @notice Check if a role is an admin role
    /// @param role The role to check
    /// @return True if the role is an admin role
    function isAdminRole(uint256 role) public pure returns (bool) {
        return _getRoleLevel(role) >= LEVEL_ADMIN;
    }

    /// @notice Check if two roles are in the same domain
    /// @param role1 First role
    /// @param role2 Second role
    /// @return True if both roles belong to the same domain
    function isSameDomain(uint256 role1, uint256 role2) public pure returns (bool) {
        return _getRoleDomain(role1) == _getRoleDomain(role2);
    }


    /// @notice Get the domain value for a role
    /// @param role The role to get the domain for
    /// @return The domain value
    function getDomain(uint256 role) public pure returns (uint256) {
        return _getRoleDomain(role);
    }

    /// @notice Helper to get the privilege level from a role
    /// @param role The role to extract the level from
    /// @return The privilege level of the role
    function _getRoleLevel(uint256 role) internal pure returns (uint256) {
        return role & 0xF00000;
    }

    /// @notice Helper to get the function domain from a role
    /// @param role The role to extract the domain from
    /// @return The function domain of the role
    function _getRoleDomain(uint256 role) internal pure returns (uint256) {
        return role & 0x00FF00;
    }

    /// @notice Helper to get the role identifier from a role
    /// @param role The role to extract the ID from
    /// @return The identifier of the role
    function _getRoleId(uint256 role) internal pure returns (uint256) {
        return role & 0x0000FF;
    }

    /// @notice Internal function to check if an address can manage a specific role
    /// @param manager The address to check for management permission
    /// @param role The role being managed
    /// @return True if the manager can grant/revoke the role
    function _canManageRole(address manager, uint256 role) internal view virtual returns (bool) {
        // Owner can manage any role
        if (manager == owner()) {
            return true;
        }

        // Get all roles the manager has
        uint256 managerRoles = roles[manager];
        if (managerRoles == 0) {
            return false;
        }

        // Check if manager has PROTOCOL_ADMIN role
        if (managerRoles & PROTOCOL_ADMIN != 0) {
            return true;
        }

        // Get the target role components
        uint256 targetLevel = _getRoleLevel(role);
        uint256 targetDomain = _getRoleDomain(role);

        // Iterate through possible roles the manager might have
        // This is a bit brute force but works for a small number of roles
        // and avoids complex state management

        // Check if manager has functional admin role for the same domain
        // and the target role is of lower level
        for (uint256 i = 0; i < 64; i++) {  // Max 64 roles as a practical limit
            uint256 checkRole = 1 << i;
            if (managerRoles & checkRole != 0) {
                uint256 managerLevel = _getRoleLevel(checkRole);
                uint256 managerDomain = _getRoleDomain(checkRole);

                // If manager's role has higher privilege than target role
                // and in the same domain, they can manage it
                if (managerLevel > targetLevel && managerDomain == targetDomain) {
                    return true;
                }
            }
        }

        return false;
    }

    /// @notice Internal function to validate if a user can grant a role
    /// @param role The role to check granting permissions for
    function _validateRoleGrant(uint256 role) internal view virtual {
        if (!_canManageRole(msg.sender, role)) {
            revert Unauthorized();
        }
    }

    /// @notice Internal function to validate if a user can revoke a role
    /// @param role The role to check revoking permissions for
    function _validateRoleRevoke(uint256 role) internal view virtual {
        if (!_canManageRole(msg.sender, role)) {
            revert Unauthorized();
        }
    }
}