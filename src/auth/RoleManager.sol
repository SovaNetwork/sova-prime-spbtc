// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title RoleManager
/// @notice Central role management contract for the Fountfi protocol
/// @dev Uses hierarchical bitmasks for core roles. Owner/PROTOCOL_ADMIN have override.
contract RoleManager is OwnableRoles {

    // --- Hierarchical Role Definitions ---

    // Define unique "flag" bits for roles that can manage others
    uint256 internal constant FLAG_PROTOCOL_ADMIN = 1 << 0; // Bit 0 = Protocol Admin Authority
    uint256 internal constant FLAG_STRATEGY_ADMIN = 1 << 1; // Bit 1 = Strategy Admin Authority
    uint256 internal constant FLAG_RULES_ADMIN    = 1 << 2; // Bit 2 = Rules Admin Authority

    // Define unique bits for base operational roles
    uint256 internal constant BASE_STRATEGY_OPERATOR = 1 << 8; // Bit 8 = Strategy Operator Permission
    uint256 internal constant BASE_KYC_OPERATOR      = 1 << 9; // Bit 9 = KYC Operator Permission

    // Operational Roles (just their base permission bit)
    uint256 public constant STRATEGY_OPERATOR = BASE_STRATEGY_OPERATOR; // Value: 1 << 8
    uint256 public constant KYC_OPERATOR      = BASE_KYC_OPERATOR;      // Value: 1 << 9

    // Domain Admin Roles (include their own flag + the base permissions they manage)
    uint256 public constant STRATEGY_ADMIN = FLAG_STRATEGY_ADMIN | BASE_STRATEGY_OPERATOR; // Value: (1<<1) | (1<<8)
    uint256 public constant RULES_ADMIN    = FLAG_RULES_ADMIN    | BASE_KYC_OPERATOR;      // Value: (1<<2) | (1<<9)

    // Protocol Admin Role (includes its flag + the admin roles it manages)
    uint256 public constant PROTOCOL_ADMIN = FLAG_PROTOCOL_ADMIN | STRATEGY_ADMIN | RULES_ADMIN;

    // Custom errors
    error InvalidRole();
    error Unauthorized(); // Using the simplified error
    error OwnerCannotRenounceAdmin();

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
        // Grant PROTOCOL_ADMIN (which includes sub-admin/operator bits) to deployer
        _grantRoles(msg.sender, PROTOCOL_ADMIN);

        // Emit event for easier off-chain tracking
        emit RoleGranted(msg.sender, PROTOCOL_ADMIN, address(0));
    }

    /// @notice Grants a role to a user
    /// @param user The address of the user to grant the role to
    /// @param role The role to grant
    function grantRole(address user, uint256 role) public payable virtual {
        // Check authorization using the hierarchical logic
        if (!_canManageRole(msg.sender, role)) {
            revert Unauthorized();
        }

        if (role == 0) revert InvalidRole(); // Prevent granting role 0

        // Grant the role
        _grantRoles(user, role);

        // Emit event
        emit RoleGranted(user, role, msg.sender);
    }

    /// @notice Revokes a role from a user
    /// @param user The address of the user to revoke the role from
    /// @param role The role to revoke
    function revokeRole(address user, uint256 role) public payable virtual {
        // Check authorization using the hierarchical logic
        if (!_canManageRole(msg.sender, role)) {
            revert Unauthorized();
        }

        if (role == 0) revert InvalidRole(); // Prevent revoking role 0

        // Revoke the role
        _removeRoles(user, role);

        // Emit event
        emit RoleRevoked(user, role, msg.sender);
    }

    /// @notice Allows a user to renounce their own role
    /// @param role The role to renounce
    function renounceRole(uint256 role) public payable virtual {
        if (role == 0) revert InvalidRole();
        // Owner cannot renounce the PROTOCOL_ADMIN role
        if (role == PROTOCOL_ADMIN && msg.sender == owner()) revert OwnerCannotRenounceAdmin();

        _removeRoles(msg.sender, role);

        // Emit event
        emit RoleRevoked(msg.sender, role, msg.sender);
    }

    /// @notice Internal function to check if an address can manage a specific role
    /// @dev Leverages hierarchical bitmasks. Manager must possess all target role bits plus additional bits.
    /// @param manager The address to check for management permission
    /// @param role The role being managed
    /// @return True if the manager can grant/revoke the role
    function _canManageRole(address manager, uint256 role) internal view virtual returns (bool) {
        // Owner can always manage any role.
        if (manager == owner()) {
            return true;
        }

        // PROTOCOL_ADMIN can manage any role *except* PROTOCOL_ADMIN itself.
        // (Only the owner can grant/revoke PROTOCOL_ADMIN to others).
        if (hasAllRoles(manager, PROTOCOL_ADMIN)) {
            return role != PROTOCOL_ADMIN;
        }

        // --- Specific Hierarchical Checks ---
        // Check if the manager holds the *required Admin role* for the target role.

        if (role == STRATEGY_OPERATOR) {
            // STRATEGY_OPERATOR is managed by STRATEGY_ADMIN
            // We use hasAllRoles to ensure the manager has the complete STRATEGY_ADMIN role (flag + base).
            return hasAllRoles(manager, STRATEGY_ADMIN);
        } else if (role == KYC_OPERATOR) {
            // KYC_OPERATOR is managed by RULES_ADMIN
            return hasAllRoles(manager, RULES_ADMIN);
        } else if (role == STRATEGY_ADMIN || role == RULES_ADMIN) {
            // STRATEGY_ADMIN and RULES_ADMIN are managed only by PROTOCOL_ADMIN.
            // Since the PROTOCOL_ADMIN check passed above without returning true,
            // the manager cannot be PROTOCOL_ADMIN, so they cannot manage these roles.
            return false;
        }
        // Add checks here if other roles (like DATA_PROVIDER, if re-added)
        // have specific non-PROTOCOL_ADMIN managers.
        // else if (role == DATA_PROVIDER) { return hasAllRoles(manager, REPORTER_ADMIN); }


        // If the role doesn't match any specific management rule above,
        // management is denied (as owner/PROTOCOL_ADMIN cases were handled).
        return false;
    }
}