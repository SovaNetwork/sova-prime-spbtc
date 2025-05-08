// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {RoleManager} from "./RoleManager.sol";

/// @title LibRoleManaged
/// @notice Library for role-managed contracts
abstract contract LibRoleManaged {
    // Custom errors
    error UnauthorizedRole(address caller, uint256 roleRequired);

    // Events
    event RoleCheckPassed(address indexed user, uint256 indexed role);

    /// @notice The role manager contract
    RoleManager public roleManager;

    /**
     * @notice Get the registry contract
     * @return The address of the registry contract
     */
    function registry() public view returns (address) {
        return roleManager.registry();
    }

    /**
     * @notice Modifier to restrict access to addresses with a specific role
     * @param role The role required to access the function
     */
    modifier onlyRoles(uint256 role) {
        if (!roleManager.hasAnyRole(msg.sender, role)) {
            revert UnauthorizedRole(msg.sender, role);
        }
        emit RoleCheckPassed(msg.sender, role);
        _;
    }

    /**
     * @notice Check if an address has a specific role
     * @param user The address to check
     * @param role The role to check for
     * @return True if the user has the role, false otherwise
     */
    function hasAnyRole(address user, uint256 role) public view returns (bool) {
        return roleManager.hasAnyRole(user, role);
    }

    /**
     * @notice Check if an address has any of the specified roles
     * @param user The address to check
     * @param roles The roles to check for
     * @return True if the user has any of the roles, false otherwise
     */
    function hasAllRoles(address user, uint256 roles) public view returns (bool) {
        return roleManager.hasAllRoles(user, roles);
    }
}