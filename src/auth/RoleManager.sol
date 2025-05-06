// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IRoleManager} from "./IRoleManager.sol";

/// @title RoleManager
/// @notice Central role management contract for the Fountfi protocol
/// @dev Uses hierarchical bitmasks for core roles. Owner/PROTOCOL_ADMIN have override.
contract RoleManager is OwnableRoles, IRoleManager {

    // --- Hierarchical Role Definitions ---

    // Define unique "flag" bits for roles that can manage others
    uint256 internal constant FLAG_PROTOCOL_ADMIN = 1 << 0; // Bit 0 = Protocol Admin Authority
    uint256 internal constant FLAG_STRATEGY_ADMIN = 1 << 1; // Bit 1 = Strategy Admin Authority
    uint256 internal constant FLAG_RULES_ADMIN    = 1 << 2; // Bit 2 = Rules Admin Authority

    // Operational Roles (just their base permission bit)
    uint256 public constant STRATEGY_OPERATOR = 1 << 8; // Value: 1 << 8
    uint256 public constant KYC_OPERATOR      = 1 << 9;      // Value: 1 << 9

    // Domain Admin Roles (include their own flag + the base permissions they manage)
    uint256 public constant STRATEGY_ADMIN = FLAG_STRATEGY_ADMIN | STRATEGY_OPERATOR; // Value: (1<<1) | (1<<8)
    uint256 public constant RULES_ADMIN    = FLAG_RULES_ADMIN    | KYC_OPERATOR;      // Value: (1<<2) | (1<<9)

    // Protocol Admin Role (includes its flag + the admin roles it manages)
    uint256 public constant PROTOCOL_ADMIN = FLAG_PROTOCOL_ADMIN | STRATEGY_ADMIN | RULES_ADMIN;

    // --- Management Hierarchy State ---

    /// @notice Mapping from a target role to the specific (admin) role required to manage it.
    /// @dev If a role maps to 0, only owner or PROTOCOL_ADMIN can manage it.
    mapping(uint256 => uint256) public roleAdminRole;

    // Custom errors
    error InvalidRole();
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

    /// @notice Emitted when the admin role for a target role is updated.
    /// @param targetRole The role whose admin is being changed.
    /// @param adminRole The new role required to manage the targetRole (0 means revert to owner/PROTOCOL_ADMIN).
    /// @param sender The address that performed the change.
    event RoleAdminSet(uint256 indexed targetRole, uint256 indexed adminRole, address indexed sender);

    /// @notice Constructor that sets up the initial roles
    /// @dev Initializes the owner and grants PROTOCOL_ADMIN role to the deployer
    constructor() {
        if (msg.sender == address(0)) revert InvalidRole();

        _initializeOwner(msg.sender);
        // Grant PROTOCOL_ADMIN (which includes sub-admin/operator bits) to deployer
        _grantRoles(msg.sender, PROTOCOL_ADMIN);

        // Emit event for easier off-chain tracking
        emit RoleGranted(msg.sender, PROTOCOL_ADMIN, address(0));

        // --- Set initial management hierarchy ---
        // Use internal helper or direct writes + emits
        _setInitialAdminRole(STRATEGY_OPERATOR, STRATEGY_ADMIN);
        _setInitialAdminRole(KYC_OPERATOR, RULES_ADMIN);
        // Add initial setup for other roles if needed (e.g., DATA_PROVIDER managed by REPORTER_ADMIN)
        // _setInitialAdminRole(DATA_PROVIDER, REPORTER_ADMIN);
    }

    /// @notice Grants a role to a user
    /// @param user The address of the user to grant the role to
    /// @param role The role to grant
    function grantRole(address user, uint256 role) public virtual override {
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
    function revokeRole(address user, uint256 role) public virtual override {
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
        if (hasAllRoles(manager, PROTOCOL_ADMIN)) {
            return role != PROTOCOL_ADMIN;
        }

        // --- Check Explicit Mapping ---
        uint256 requiredAdminRole = roleAdminRole[role];

        if (requiredAdminRole != 0) {
            // If an explicit admin role is defined, the manager MUST have that specific role.
            // Use hasAllRoles for strict check against the required composite admin role.
            return hasAllRoles(manager, requiredAdminRole);
        }

        // If no explicit admin role is set in the mapping (requiredAdminRole == 0),
        // management is denied (as owner/PROTOCOL_ADMIN cases were handled).
        // This covers roles not explicitly configured or roles whose admin was set to 0.
        return false;
    }

    /// @notice Sets the specific role required to manage a target role.
    /// @dev Requires the caller to have the PROTOCOL_ADMIN role or be the owner.
    /// @param targetRole The role whose admin role is to be set. Cannot be PROTOCOL_ADMIN.
    /// @param adminRole The role that will be required to manage the targetRole. Set to 0 to require owner/PROTOCOL_ADMIN.
    function setRoleAdmin(uint256 targetRole, uint256 adminRole) external virtual {
        // Authorization: Only Owner or PROTOCOL_ADMIN
        // Use hasAllRoles for the strict check against the composite PROTOCOL_ADMIN role
        if (msg.sender != owner() && !hasAllRoles(msg.sender, PROTOCOL_ADMIN)) {
             revert Unauthorized();
        }

        // Prevent managing PROTOCOL_ADMIN itself via this mechanism or setting role 0
        if (targetRole == 0 || targetRole == PROTOCOL_ADMIN) revert InvalidRole();
        // Optional: Add validation for adminRole format if desired

        roleAdminRole[targetRole] = adminRole;

        emit RoleAdminSet(targetRole, adminRole, msg.sender);
    }

    /// @notice Internal helper to set initial admin roles during construction
    /// @dev Does not perform authorization checks.
    function _setInitialAdminRole(uint256 targetRole, uint256 adminRole) internal {
        roleAdminRole[targetRole] = adminRole;

        // Emit event with contract address as sender for setup clarity
        emit RoleAdminSet(targetRole, adminRole, address(this));
    }
}