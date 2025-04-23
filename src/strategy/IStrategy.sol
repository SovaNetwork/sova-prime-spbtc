// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IStrategy
 * @notice Interface for tRWA investment strategies
 * @dev Defines the interface for strategies that manage tRWA token assets
 */
interface IStrategy {
    // Errors
    error InvalidAddress();
    error InvalidRules();
    error Unauthorized();
    error CallRevert(bytes returnData);
    error AlreadyInitialized();

    // Events
    event PendingAdminChange(address indexed oldAdmin, address indexed newAdmin);
    event AdminChange(address indexed oldAdmin, address indexed newAdmin);
    event NoAdminChange(address indexed oldAdmin, address indexed cancelledAdmin);
    event ManagerChange(address indexed oldManager, address indexed newManager);
    event Call(address indexed target, uint256 value, bytes data);
    event StrategyInitialized(address indexed admin, address indexed manager, address indexed asset, address sToken);

    // Initialization
    function initialize(
        string calldata name,
        string calldata symbol,
        address admin,
        address manager,
        address asset,
        address rules,
        bytes memory initData
    ) external;

    // Role Management
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function manager() external view returns (address);
    function asset() external view returns (address);
    function sToken() external view returns (address);

    function setManager(address newManager) external;
    function proposeAdmin(address newAdmin) external;
    function acceptAdmin() external;
    function cancelAdminChange() external;

    // Asset Management
    function balance() external view returns (uint256);
    
    // Transfer assets from the strategy to a user
    function transferAssets(address user, uint256 amount) external;
}
