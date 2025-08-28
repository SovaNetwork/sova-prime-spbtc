// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ReportedStrategy} from "./ReportedStrategy.sol";
import {BtcVaultToken} from "../token/BtcVaultToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/**
 * @title BtcVaultStrategy
 * @notice Multi-collateral BTC vault strategy based on ManagedWithdrawRWAStrategy pattern
 * @dev Extends ReportedStrategy, manages multiple BTC collateral types with managed withdrawals
 */
contract BtcVaultStrategy is ReportedStrategy {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetNotSupported();
    error AssetAlreadySupported();
    error InvalidDecimals();
    error InsufficientLiquidity();
    error InvalidAmount();
    error UnauthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralAdded(address indexed token, uint8 decimals);
    event CollateralRemoved(address indexed token);
    event LiquidityAdded(uint256 amount);
    event LiquidityRemoved(uint256 amount);
    event CollateralWithdrawn(address indexed token, uint256 amount, address indexed to);
    event CollateralDeposited(address indexed depositor, address indexed token, uint256 amount);
    event LiquidityNotified(address indexed token, uint256 amount, uint256 newAvailable);
    event LiquiditySynced(uint256 oldAvailable, uint256 newAvailable);

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Inline asset registry - supported BTC collateral tokens
    mapping(address => bool) public supportedAssets;

    /// @notice Decimals for each supported asset (typically 8 for BTC tokens)
    mapping(address => uint8) public collateralDecimals;

    /// @notice Array of supported collateral addresses for enumeration
    address[] public collateralTokens;

    /// @notice sovaBTC available for redemptions
    uint256 public availableLiquidity;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy
     * @param name_ The name of the strategy
     * @param symbol_ The symbol of the strategy
     * @param roleManager_ The role manager address
     * @param manager_ The manager address
     * @param sovaBTC_ The sovaBTC address (asset for redemptions)
     * @param assetDecimals_ Decimals of sovaBTC (should be 8)
     * @param initData Encoded initialization data containing reporter address
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address sovaBTC_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public virtual override {
        // Call parent initialization which sets up reporter and deploys token
        super.initialize(name_, symbol_, roleManager_, manager_, sovaBTC_, assetDecimals_, initData);

        // sovaBTC is always a supported asset for liquidity
        supportedAssets[sovaBTC_] = true;
        collateralDecimals[sovaBTC_] = assetDecimals_;
        collateralTokens.push(sovaBTC_);
    }

    /**
     * @notice Deploy a new BtcVaultToken for this strategy
     * @dev Override from BasicStrategy to deploy our custom token type
     */
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 assetDecimals_)
        internal
        virtual
        override
        returns (address)
    {
        // Deploy BtcVaultToken which supports multi-collateral deposits
        BtcVaultToken newToken = new BtcVaultToken(name_, symbol_, asset_, address(this));

        return address(newToken);
    }

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new supported collateral token
     * @param token Address of the BTC collateral token
     * @param decimals_ Decimals of the token (must be 8 for BTC tokens)
     */
    function addCollateral(address token, uint8 decimals_) external onlyManager {
        if (token == address(0)) revert InvalidAddress();
        if (supportedAssets[token]) revert AssetAlreadySupported();
        if (decimals_ != 8) revert InvalidDecimals(); // All BTC tokens should have 8 decimals

        supportedAssets[token] = true;
        collateralDecimals[token] = decimals_;
        collateralTokens.push(token);

        emit CollateralAdded(token, decimals_);
    }

    /**
     * @notice Remove a supported collateral token
     * @param token Address of the collateral token to remove
     */
    function removeCollateral(address token) external onlyManager {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (token == asset) revert InvalidAddress(); // Cannot remove sovaBTC

        supportedAssets[token] = false;
        delete collateralDecimals[token];

        // Remove from array
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == token) {
                collateralTokens[i] = collateralTokens[collateralTokens.length - 1];
                collateralTokens.pop();
                break;
            }
        }

        emit CollateralRemoved(token);
    }

    /**
     * @notice Deposit collateral directly to the strategy
     * @param token The collateral token to deposit
     * @param amount The amount to deposit
     */
    function depositCollateral(address token, uint256 amount) external {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (amount == 0) revert InvalidAmount();

        // Transfer collateral from sender to strategy
        token.safeTransferFrom(msg.sender, address(this), amount);

        // If depositing sovaBTC, increase available liquidity
        if (token == asset) {
            availableLiquidity += amount;
        }

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /**
     * @notice Notify strategy of collateral deposit from BtcVaultToken
     * @dev CRITICAL FIX: This function ensures availableLiquidity stays in sync when
     * deposits come through BtcVaultToken.depositCollateral() instead of directly to strategy.
     * Includes defensive accounting to prevent availableLiquidity from exceeding actual balance.
     * @param token The collateral token that was deposited
     * @param amount The amount that was deposited
     */
    function notifyCollateralDeposit(address token, uint256 amount) external {
        // Only the token contract can call this function
        if (msg.sender != sToken) revert UnauthorizedCaller();
        
        // If the deposited token is sovaBTC, update available liquidity
        if (token == asset) {
            // DEFENSIVE ACCOUNTING: Clamp availableLiquidity to never exceed actual balance
            // This handles edge cases:
            // 1. Someone sends sovaBTC directly to strategy (bypassing deposit functions)
            // 2. Duplicate notifications due to bugs or retries
            // 3. Any other unexpected balance changes
            uint256 actualBalance = IERC20(asset).balanceOf(address(this));
            uint256 newAvailable = availableLiquidity + amount;
            
            // Clamp to actual balance - self-healing approach to maintain invariant
            availableLiquidity = newAvailable > actualBalance ? actualBalance : newAvailable;
            
            // Log this liquidity update with full details for transparency
            emit LiquidityNotified(token, amount, availableLiquidity);
        }
        
        // Note: For other collateral types (WBTC, tBTC, etc.), 
        // no liquidity tracking is needed as they're not used for redemptions
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add sovaBTC liquidity for redemptions
     * @param amount Amount of sovaBTC to add
     */
    function addLiquidity(uint256 amount) external onlyManager {
        if (amount == 0) revert InvalidAmount();

        // Transfer sovaBTC from manager
        asset.safeTransferFrom(msg.sender, address(this), amount);
        availableLiquidity += amount;

        emit LiquidityAdded(amount);
    }

    /**
     * @notice Remove excess sovaBTC liquidity
     * @param amount Amount of sovaBTC to remove
     * @param to Address to send the sovaBTC
     */
    function removeLiquidity(uint256 amount, address to) external onlyManager {
        if (amount == 0) revert InvalidAmount();
        if (amount > availableLiquidity) revert InsufficientLiquidity();
        if (to == address(0)) revert InvalidAddress();

        availableLiquidity -= amount;
        asset.safeTransfer(to, amount);

        emit LiquidityRemoved(amount);
    }

    /**
     * @notice Withdraw collateral to admin (emergency or rebalancing)
     * @param token Collateral token to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdrawCollateral(address token, uint256 amount, address to) external onlyManager {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert InvalidAddress();

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (amount > tokenBalance) revert InsufficientLiquidity();

        // CRITICAL FIX: Properly decrement availableLiquidity for sovaBTC withdrawals
        // This maintains the invariant that availableLiquidity <= actual sovaBTC balance
        if (token == asset) {
            // Strict enforcement: revert if trying to withdraw more than tracked liquidity
            // This prevents the accounting from drifting
            if (amount > availableLiquidity) revert InsufficientLiquidity();
            availableLiquidity -= amount;
        }

        token.safeTransfer(to, amount);
        emit CollateralWithdrawn(token, amount, to);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL SUPPORT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sync availableLiquidity to actual sovaBTC balance
     * @dev Manager-only function to reconcile any drift in liquidity tracking.
     * Handles cases where sovaBTC was sent directly to the strategy or other
     * unexpected balance changes. Only decreases availableLiquidity, never increases it.
     */
    function syncAvailableLiquidity() external onlyManager {
        uint256 actualBalance = IERC20(asset).balanceOf(address(this));
        
        // Only adjust downward - this prevents accidentally counting non-redemption funds
        if (availableLiquidity > actualBalance) {
            uint256 oldAvailable = availableLiquidity;
            availableLiquidity = actualBalance;
            
            // Emit event for transparency and tracking
            emit LiquiditySynced(oldAvailable, availableLiquidity);
        }
    }

    /**
     * @notice Approve token to withdraw assets during redemptions
     * @dev Called before redemptions to allow token to pull sovaBTC
     */
    function approveTokenWithdrawal() external onlyManager {
        // Zero-first approval pattern for compatibility with tokens that require it
        asset.safeApprove(sToken, 0);
        asset.safeApprove(sToken, availableLiquidity);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if an asset is supported
     * @param token Address of the token to check
     * @return Whether the token is supported
     */
    function isSupportedAsset(address token) external view returns (bool) {
        return supportedAssets[token];
    }

    /**
     * @notice Get list of all supported collateral tokens
     * @return Array of supported token addresses
     */
    function getSupportedCollaterals() external view returns (address[] memory) {
        return collateralTokens;
    }

    /**
     * @notice Get total collateral assets value in sovaBTC terms (1:1 for all BTC variants)
     * @dev This sums raw collateral balances without NAV adjustment
     * @return Total value of all collateral in 8 decimal units
     */
    function totalCollateralAssets() external view returns (uint256) {
        uint256 total = 0;

        // Sum all collateral balances (all have 1:1 value with sovaBTC)
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            total += tokenBalance; // All BTC tokens are 8 decimals, 1:1 with sovaBTC
        }

        return total;
    }

    /**
     * @notice Get balance of a specific collateral token
     * @param token Address of the collateral token
     * @return Balance of the token held by strategy
     */
    function collateralBalance(address token) external view returns (uint256) {
        if (!supportedAssets[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Get available liquidity for redemptions
     * @return Amount of sovaBTC available
     */
    function getAvailableLiquidity() external view returns (uint256) {
        return availableLiquidity;
    }
}
