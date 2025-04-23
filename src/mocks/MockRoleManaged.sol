// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {RoleManaged} from "../auth/RoleManaged.sol";
import {IRoleManager} from "../auth/IRoleManager.sol";

/// @title MockRoleManaged
/// @notice Mock contract for testing role-based access control
contract MockRoleManaged is RoleManaged {
    uint256 public counter;
    
    event CounterIncremented(address operator, uint256 newValue);
    
    constructor(address _roleManager) RoleManaged(_roleManager) {}
    
    /// @notice Function that can only be called by PROTOCOL_ADMIN
    function incrementAsProtocolAdmin() external onlyRole(roleManager.PROTOCOL_ADMIN()) {
        counter++;
        emit CounterIncremented(msg.sender, counter);
    }
    
    /// @notice Function that can only be called by REGISTRY_ADMIN
    function incrementAsRegistryAdmin() external onlyRole(roleManager.REGISTRY_ADMIN()) {
        counter++;
        emit CounterIncremented(msg.sender, counter);
    }
    
    /// @notice Function that can be called by either STRATEGY_ADMIN or STRATEGY_MANAGER
    function incrementAsStrategyRole() external {
        uint256[] memory roles = new uint256[](2);
        roles[0] = roleManager.STRATEGY_ADMIN();
        roles[1] = roleManager.STRATEGY_MANAGER();
        
        if (!roleManager.hasAnyOfRoles(msg.sender, roles)) {
            revert("Unauthorized");
        }
        
        counter++;
        emit CounterIncremented(msg.sender, counter);
    }
    
    /// @notice Function that can be called by KYC_ADMIN
    function incrementAsKycAdmin() external onlyRole(roleManager.KYC_ADMIN()) {
        counter++;
        emit CounterIncremented(msg.sender, counter);
    }
    
    /// @notice Function that can be called by KYC_OPERATOR
    function incrementAsKycOperator() external onlyRole(roleManager.KYC_OPERATOR()) {
        counter++;
        emit CounterIncremented(msg.sender, counter);
    }
    
    /// @notice Get the current counter value - no restrictions
    function getCounter() external view returns (uint256) {
        return counter;
    }
}