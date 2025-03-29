// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ItRWA
 * @notice Interface for Tokenized Real World Asset (tRWA)
 * @dev Defines the interface with all events and errors for the tRWA contract
 */
interface ItRWA {
    // Configuration struct for deployment
    struct ConfigurationStruct {
        address admin;
        address priceAuthority;
        address subscriptionManager;
        address underlyingAsset;
    }

    // Roles
    function PRICE_AUTHORITY_ROLE() external view returns (uint256);
    function ADMIN_ROLE() external view returns (uint256);
    function SUBSCRIPTION_ROLE() external view returns (uint256);

    // Events
    event UnderlyingValueUpdated(uint256 newUnderlyingPerToken, uint256 timestamp);
    event TransferApprovalUpdated(address indexed oldModule, address indexed newModule);
    event TransferApprovalToggled(bool enabled);
    event TransferRejected(address indexed from, address indexed to, uint256 value, string reason);
    event HookAdded(uint256 indexed hookId, address indexed hook);
    event HookRemoved(uint256 indexed hookId);
    event HookStatusChanged(uint256 indexed hookId, bool active);

    // Errors
    error InvalidAddress();
    error ZeroAssets();
    error ZeroShares();
    error InvalidTransferApprovalAddress();
    error TransferBlocked(string reason);
    error InvalidUnderlyingValue();
    error HookReverted(uint256 hookId);
    error WithdrawMoreThanMax();
    error RedeemMoreThanMax();

    // Main interface functions
    function transferApproval() external view returns (address);
    function underlyingPerToken() external view returns (uint256);
    function lastValueUpdate() external view returns (uint256);
    function transferApprovalEnabled() external view returns (bool);
    function totalUnderlying() external view returns (uint256);

    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external;
    function setTransferApproval(address _transferApproval) external;
    function toggleTransferApproval(bool _enabled) external;

    // Hook management functions
    function addHook(address hook) external returns (uint256);
    function removeHook(uint256 hookId) external;
    function setHookStatus(uint256 hookId, bool active) external;
    function getHook(uint256 hookId) external view returns (address, bool);
}