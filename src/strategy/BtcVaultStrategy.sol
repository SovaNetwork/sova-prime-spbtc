// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ReportedStrategy} from "./ReportedStrategy.sol";
import {BtcVaultToken} from "../token/BtcVaultToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// Minimal interface for decimals check
interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

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

    /// @notice All BTC collateral tokens must have 8 decimals
    uint8 public constant COLLATERAL_DECIMALS = 8;

    /// @notice Inline asset registry - supported BTC collateral tokens
    mapping(address => bool) public supportedAssets;

    /// @notice Array of supported collateral addresses for enumeration
    address[] public collateralTokens;

    // Note: availableLiquidity tracking removed - using actual balance instead for simplicity

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

        // sovaBTC is always a supported asset
        // Verify it has the correct decimals
        if (assetDecimals_ != COLLATERAL_DECIMALS) revert InvalidDecimals();
        supportedAssets[sovaBTC_] = true;
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
     * @dev All collateral must have 8 decimals (enforced by COLLATERAL_DECIMALS constant)
     * @param token Address of the BTC collateral token
     */
    function addCollateral(address token) external onlyManager {
        if (token == address(0)) revert InvalidAddress();
        if (supportedAssets[token]) revert AssetAlreadySupported();
        
        // Verify the token has 8 decimals
        // Note: This assumes the token implements decimals() - may revert for non-standard tokens
        try IERC20Decimals(token).decimals() returns (uint8 decimals) {
            if (decimals != COLLATERAL_DECIMALS) revert InvalidDecimals();
        } catch {
            revert InvalidDecimals();
        }

        supportedAssets[token] = true;
        collateralTokens.push(token);

        emit CollateralAdded(token, COLLATERAL_DECIMALS);
    }

    /**
     * @notice Remove a supported collateral token
     * @param token Address of the collateral token to remove
     */
    function removeCollateral(address token) external onlyManager {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (token == asset) revert InvalidAddress(); // Cannot remove sovaBTC

        supportedAssets[token] = false;

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

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add sovaBTC for redemptions
     * @param amount Amount of sovaBTC to add
     */
    function addLiquidity(uint256 amount) external onlyManager {
        if (amount == 0) revert InvalidAmount();

        // Transfer sovaBTC from manager
        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(amount);
    }

    /**
     * @notice Remove sovaBTC from strategy
     * @param amount Amount of sovaBTC to remove
     * @param to Address to send the sovaBTC
     */
    function removeLiquidity(uint256 amount, address to) external onlyManager {
        if (amount == 0) revert InvalidAmount();
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (amount > balance) revert InsufficientLiquidity();
        if (to == address(0)) revert InvalidAddress();

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

        token.safeTransfer(to, amount);
        emit CollateralWithdrawn(token, amount, to);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL SUPPORT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approve token to withdraw assets during redemptions
     * @dev Called before redemptions to allow token to pull sovaBTC
     * @param amount Amount to approve for withdrawal
     */
    function approveTokenWithdrawal(uint256 amount) external onlyManager {
        // Zero-first approval pattern for compatibility with tokens that require it
        asset.safeApprove(sToken, 0);
        asset.safeApprove(sToken, amount);
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
     * @notice Get available sovaBTC balance for redemptions
     * @return Current sovaBTC balance in the strategy
     */
    function availableLiquidity() external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}
