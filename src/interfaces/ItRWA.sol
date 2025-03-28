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

    // Errors
    error InvalidAddress();
    error ZeroAssets();
    error ZeroShares();
    error InvalidTransferApprovalAddress();
    error TransferBlocked(string reason);
    error InvalidUnderlyingValue();

    // Main interface functions
    function transferApproval() external view returns (address);
    function underlyingPerToken() external view returns (uint256);
    function lastValueUpdate() external view returns (uint256);
    function transferApprovalEnabled() external view returns (bool);
    function totalUnderlying() external view returns (uint256);

    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external;
    function setTransferApproval(address _transferApproval) external;
    function toggleTransferApproval(bool _enabled) external;
}