// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) inheriting ERC4626 standard
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC4626, OwnableRoles, ItRWA {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    // Role definitions
    uint256 public constant PRICE_AUTHORITY_ROLE = 1 << 0;
    uint256 public constant ADMIN_ROLE = 1 << 1;
    uint256 public constant SUBSCRIPTION_ROLE = 1 << 2;
    uint256 public constant REDEMPTION_ROLE = 1 << 3;
    uint256 public constant MANAGER_ROLE = 1 << 4;

    // Internal storage for token metadata
    string internal _name;
    string internal _symbol;
    address internal _asset;

    address public transferApproval;
    uint256 public underlyingPerToken; // Value of underlying asset per token in USD (18 decimals)
    uint256 public lastValueUpdate; // Timestamp of last underlying value update
    bool public transferApprovalEnabled = false;

    // Asset-related state
    uint256 public totalUnderlying; // Total value of underlying assets in USD (18 decimals)
    uint256 public pendingDeposits; // Total amount of deposited assets waiting for manager withdrawal
    uint256 public pendingWithdrawals; // Total amount of assets waiting to be claimed by redeemers

    // Events
    event PendingDepositsWithdrawn(address indexed manager, uint256 amount);
    event PendingWithdrawalsFunded(address indexed manager, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);

    // Errors
    error InsufficientWithdrawalFunds();

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param config Configuration struct with all deployment parameters
     */
    constructor(
        string memory name_,
        string memory symbol_,
        ConfigurationStruct memory config
    ) {
        // Validate configuration parameters
        if (config.underlyingAsset == address(0)) revert InvalidAddress();
        if (config.priceAuthority == address(0)) revert InvalidAddress();
        if (config.admin == address(0)) revert InvalidAddress();
        if (config.subscriptionManager == address(0)) revert InvalidAddress();

        _name = name_;
        _symbol = symbol_;
        _asset = config.underlyingAsset;

        // Initialize owner to the admin address from config
        _initializeOwner(config.admin);

        // Grant the roles as specified in the config
        _grantRoles(config.admin, ADMIN_ROLE);
        _grantRoles(config.priceAuthority, PRICE_AUTHORITY_ROLE);
        _grantRoles(config.subscriptionManager, SUBSCRIPTION_ROLE);
        _grantRoles(config.admin, MANAGER_ROLE); // Default admin as manager

        lastValueUpdate = block.timestamp;
    }

    /**
     * @notice Returns the name of the token
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the decimals places of the token
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the underlying asset address
     * @return Address of the underlying ERC20 token
     */
    function asset() public view virtual override returns (address) {
        return _asset;
    }

    /**
     * @notice Update the underlying value per token
     * @param _newUnderlyingPerToken New underlying value per token in USD (18 decimals)
     */
    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external onlyRoles(PRICE_AUTHORITY_ROLE) {
        if (_newUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        // Calculate the total underlying value based on current shares
        uint256 supply = totalSupply();
        if (supply > 0) {
            totalUnderlying = supply * _newUnderlyingPerToken / 1e18;
        }

        underlyingPerToken = _newUnderlyingPerToken;
        lastValueUpdate = block.timestamp;

        emit UnderlyingValueUpdated(_newUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Set or update the transfer approval module
     * @param _transferApproval Address of the transfer approval module
     */
    function setTransferApproval(address _transferApproval) external onlyOwnerOrRoles(ADMIN_ROLE) {
        if (_transferApproval == address(0)) revert InvalidTransferApprovalAddress();

        address oldModule = transferApproval;
        transferApproval = _transferApproval;

        emit TransferApprovalUpdated(oldModule, _transferApproval);
    }

    /**
     * @notice Enable or disable transfer approval checks
     * @param _enabled Whether transfer approval is enabled
     */
    function toggleTransferApproval(bool _enabled) external onlyOwnerOrRoles(ADMIN_ROLE) {
        transferApprovalEnabled = _enabled;

        emit TransferApprovalToggled(_enabled);
    }

    /**
     * @notice Withdraw pending deposits by a manager
     * @param amount Amount of tokens to withdraw
     * @param to Address to send the tokens to
     */
    function withdrawPendingDeposits(uint256 amount, address to) external onlyRoles(MANAGER_ROLE) {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAssets();
        if (amount > pendingDeposits) revert WithdrawMoreThanMax();

        pendingDeposits -= amount;
        _asset.safeTransfer(to, amount);

        emit PendingDepositsWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Fund the pending withdrawals pool for redemptions
     * @param amount Amount of tokens to add to the pending withdrawals pool
     */
    function fundPendingWithdrawals(uint256 amount) external onlyRoles(MANAGER_ROLE) {
        if (amount == 0) revert ZeroAssets();

        // Transfer assets from the manager to this contract
        _asset.safeTransferFrom(msg.sender, address(this), amount);

        // Add to pendingWithdrawals pool
        pendingWithdrawals += amount;

        emit PendingWithdrawalsFunded(msg.sender, amount);
    }

    /**
     * @notice Process a pending withdrawal for a receiver
     * @param amount Amount of tokens to process from the pending withdrawals pool
     * @param receiver Address to receive the withdrawal
     */
    function processWithdrawal(uint256 amount, address receiver) external onlyRoles(REDEMPTION_ROLE) {
        if (receiver == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAssets();
        if (amount > pendingWithdrawals) revert InsufficientWithdrawalFunds();

        pendingWithdrawals -= amount;
        _asset.safeTransfer(receiver, amount);

        emit WithdrawalProcessed(receiver, amount);
    }

    /**
     * @notice Override _beforeTokenTransfer to add transfer approval checks
     * @dev Called before any transfer, mint, or burn
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip checks for minting and burning which are controlled by admin
        if (from != address(0) && to != address(0)) {
            if (to == address(0)) revert InvalidAddress();

            // Check approval if enabled
            if (transferApprovalEnabled && transferApproval != address(0)) {
                // Interface to the checkTransferApproval function
                (bool successCall, bytes memory data) = transferApproval.staticcall(
                    abi.encodeWithSignature(
                        "checkTransferApproval(address,address,address,uint256)",
                        address(this),
                        from,
                        to,
                        amount
                    )
                );

                if (!successCall || !abi.decode(data, (bool))) {
                    emit TransferRejected(from, to, amount, "Failed transfer approval check");
                    revert TransferBlocked("Failed transfer approval check");
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of the underlying assets managed by the vault
     * @return assets Total underlying assets in USD value (18 decimals)
     */
    function totalAssets() public view override returns (uint256 assets) {
        return totalUnderlying;
    }

    /**
     * @notice Deposit assets and mint shares to receiver, only callable by subscription role
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override onlyRoles(SUBSCRIPTION_ROLE) returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        // Transfer assets from the sender to this contract
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Add to pending deposits bucket
        pendingDeposits += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Mint shares to receiver by depositing assets, only callable by subscription role
     * @param shares Amount of shares to mint
     * @param receiver Address receiving the shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver) public override onlyRoles(SUBSCRIPTION_ROLE) returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        assets = previewMint(shares);
        if (assets == 0) revert ZeroAssets();

        // Transfer assets from the sender to this contract
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Add to pending deposits bucket
        pendingDeposits += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Withdraw assets by burning shares, only callable by admin
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) public override onlyOwnerOrRoles(ADMIN_ROLE) returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        shares = previewWithdraw(assets);
        if (shares == 0) revert ZeroShares();

        if (shares > balanceOf(owner))
            revert WithdrawMoreThanMax();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        // Mark as pending withdrawal to be processed later
        // Actual transfer of assets happens when processWithdrawal is called

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Redeem shares for assets, only callable by admin
     * @param shares Amount of shares to redeem
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return assets Amount of assets received
     */
    function redeem(uint256 shares, address receiver, address owner) public override onlyOwnerOrRoles(ADMIN_ROLE) returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        if (shares > balanceOf(owner))
            revert RedeemMoreThanMax();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        // Mark as pending withdrawal to be processed later
        // Actual transfer of assets happens when processWithdrawal is called

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Calculate the USD value of a given number of shares
     * @param _shares Number of shares
     * @return usdValue USD value of the shares (18 decimals)
     */
    function getUsdValue(uint256 _shares) public view returns (uint256 usdValue) {
        return convertToAssets(_shares);
    }
}