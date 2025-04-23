// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title RoleManager
/// @notice Central role management contract for the Fountfi protocol
/// @dev Based on Solady's OwnableRoles implementation
contract RoleManager is OwnableRoles {
    // Root role
    uint256 public constant PROTOCOL_ADMIN = _ROLE_0;

    // Functional roles
    uint256 public constant STRATEGY_ADMIN = _ROLE_1;
    uint256 public constant KYC_ADMIN = _ROLE_2;
    uint256 public constant REPORTER_ADMIN = _ROLE_3;
    uint256 public constant SUBSCRIPTION_ADMIN = _ROLE_4;
    uint256 public constant WITHDRAWAL_ADMIN = _ROLE_5;

    // Operational roles
    uint256 public constant STRATEGY_MANAGER = _ROLE_6;
    uint256 public constant KYC_OPERATOR = _ROLE_7;
    uint256 public constant DATA_PROVIDER = _ROLE_8;

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

    /// @notice Internal function to check if an address can manage a specific role
    /// @param manager The address to check for management permission
    /// @param role The role being managed
    /// @return True if the manager can grant/revoke the role
    function _canManageRole(address manager, uint256 role) internal view virtual returns (bool) {
        // Owner or PROTOCOL_ADMIN can manage any role
        if (manager == owner() || hasRole(manager, PROTOCOL_ADMIN)) {
            return true;
        }

        // Check if the manager is an operational role (KYC_OPERATOR, STRATEGY_MANAGER, DATA_PROVIDER)
        // Operational roles can NEVER manage other roles
        if (hasRole(manager, KYC_OPERATOR) ||
            hasRole(manager, STRATEGY_MANAGER) ||
            hasRole(manager, DATA_PROVIDER)) {
            return false;
        }

        // Special cases for functional admins that can manage their operational roles
        if (role == KYC_OPERATOR && hasRole(manager, KYC_ADMIN)) {
            return true;
        } else if (role == DATA_PROVIDER && hasRole(manager, REPORTER_ADMIN)) {
            return true;
        } else if (role == STRATEGY_MANAGER && hasRole(manager, STRATEGY_ADMIN)) {
            return true;
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