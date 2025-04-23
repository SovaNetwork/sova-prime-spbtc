// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRoleManager} from "./IRoleManager.sol";

/// @title RoleManaged
/// @notice Base contract for role-managed contracts in the Fountfi protocol
/// @dev Provides role checking functionality for contracts
abstract contract RoleManaged {
    // Role manager reference
    IRoleManager public immutable roleManager;
    
    // Custom errors
    error UnauthorizedRole(address caller, uint256 roleRequired);
    error InvalidRoleManager();
    
    // Events
    event RoleCheckPassed(address indexed user, uint256 indexed role);
    
    /// @notice Constructor that sets the role manager reference
    /// @param _roleManager Address of the role manager contract
    constructor(address _roleManager) {
        if (_roleManager == address(0)) revert InvalidRoleManager();
        roleManager = IRoleManager(_roleManager);
    }
    
    /// @notice Modifier to restrict access to addresses with a specific role
    /// @param role The role required to access the function
    modifier onlyRole(uint256 role) {
        if (!roleManager.hasRole(msg.sender, role)) {
            revert UnauthorizedRole(msg.sender, role);
        }
        emit RoleCheckPassed(msg.sender, role);
        _;
    }
    
    /// @notice Modifier to restrict access to addresses with any of the specified roles
    /// @param roles An array of roles, any of which allows access
    modifier onlyRoles(uint256[] memory roles) {
        if (!roleManager.hasAnyOfRoles(msg.sender, roles)) {
            revert UnauthorizedRole(msg.sender, 0); // Generic unauthorized error for multiple roles
        }
        emit RoleCheckPassed(msg.sender, 0); // Zero means multiple roles were checked
        _;
    }
    
    /// @notice Check if an address has a specific role
    /// @param user The address to check
    /// @param role The role to check for
    /// @return True if the user has the role, false otherwise
    function hasRole(address user, uint256 role) public view returns (bool) {
        return roleManager.hasRole(user, role);
    }
    
    /// @notice Check if an address has any of the specified roles
    /// @param user The address to check
    /// @param roles An array of roles to check for
    /// @return True if the user has any of the roles, false otherwise
    function hasAnyRole(address user, uint256[] memory roles) public view returns (bool) {
        return roleManager.hasAnyOfRoles(user, roles);
    }
    
    /// @notice Get an array containing roles for common role combinations
    /// @dev Helper function to reduce code duplication when creating role arrays
    /// @param role1 First role to include
    /// @param role2 Second role to include
    /// @return roles Array containing the specified roles
    function _getRolesArray(uint256 role1, uint256 role2) internal pure returns (uint256[] memory roles) {
        roles = new uint256[](2);
        roles[0] = role1;
        roles[1] = role2;
        return roles;
    }
}