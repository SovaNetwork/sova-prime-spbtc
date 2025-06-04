// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IRoleManager
 * @notice Interface for the RoleManager contract
 */
interface IRoleManager {
    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants a role to a user
    /// @param user The address of the user to grant the role to
    /// @param role The role to grant
    function grantRole(address user, uint256 role) external;

    /// @notice Revokes a role from a user
    /// @param user The address of the user to revoke the role from
    /// @param role The role to revoke
    function revokeRole(address user, uint256 role) external;

    /// @notice Sets the specific role required to manage a target role.
    /// @dev Requires the caller to have the PROTOCOL_ADMIN role or be the owner.
    /// @param targetRole The role whose admin role is to be set. Cannot be PROTOCOL_ADMIN.
    /// @param adminRole The role that will be required to manage the targetRole. Set to 0 to require owner/PROTOCOL_ADMIN.
    function setRoleAdmin(uint256 targetRole, uint256 adminRole) external;
}
