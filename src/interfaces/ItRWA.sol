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
        uint256 initialUnderlyingPerToken;
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

    // ERC4626 events
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    // Errors
    error InvalidAddress();
    error ZeroAssets();
    error ZeroShares();
    error InvalidTransferApprovalAddress();
    error TransferBlocked(string reason);
    error InvalidUnderlyingValue();

    // Main interface functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function asset() external view returns (address);

    function transferApproval() external view returns (address);
    function underlyingPerToken() external view returns (uint256);
    function lastValueUpdate() external view returns (uint256);
    function transferApprovalEnabled() external view returns (bool);
    function totalUnderlying() external view returns (uint256);

    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external;
    function setTransferApproval(address _transferApproval) external;
    function toggleTransferApproval(bool _enabled) external;

    // ERC4626 functions
    function totalAssets() external view returns (uint256 assets);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    // Additional functions
    function getUsdValue(uint256 _shares) external view returns (uint256 usdValue);
}