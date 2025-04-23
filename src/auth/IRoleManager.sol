// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IRoleManager
/// @notice Interface for the RoleManager contract
interface IRoleManager {
    // Role constants (must match RoleManager implementation)
    function PROTOCOL_ADMIN() external view returns (uint256);
    function STRATEGY_ADMIN() external view returns (uint256);
    function KYC_ADMIN() external view returns (uint256);
    function REPORTER_ADMIN() external view returns (uint256);
    function SUBSCRIPTION_ADMIN() external view returns (uint256);
    function WITHDRAWAL_ADMIN() external view returns (uint256);
    function RULES_ADMIN() external view returns (uint256);
    function STRATEGY_MANAGER() external view returns (uint256);
    function KYC_OPERATOR() external view returns (uint256);
    function DATA_PROVIDER() external view returns (uint256);

    /// @notice Grants a role to a user
    /// @param user The address of the user to grant the role to
    /// @param role The role to grant
    function grantRole(address user, uint256 role) external payable;

    /// @notice Revokes a role from a user
    /// @param user The address of the user to revoke the role from
    /// @param role The role to revoke
    function revokeRole(address user, uint256 role) external payable;
    
    /// @notice Allows a user to renounce their own role
    /// @param role The role to renounce
    function renounceRole(uint256 role) external payable;

    /// @notice Checks if a user has a specific role
    /// @param user The address of the user to check
    /// @param role The role to check for
    /// @return True if the user has the role, false otherwise
    function hasRole(address user, uint256 role) external view returns (bool);
    
    /// @notice Batch checking if a user has any of the specified roles
    /// @param user The address of the user to check
    /// @param roles An array of roles to check for
    /// @return True if the user has any of the roles, false otherwise
    function hasAnyOfRoles(address user, uint256[] calldata roles) external view returns (bool);
    
    /// @notice Batch checking if a user has all of the specified roles
    /// @param user The address of the user to check
    /// @param roles An array of roles to check for
    /// @return True if the user has all of the roles, false otherwise
    function hasAllRoles(address user, uint256[] calldata roles) external view returns (bool);
}