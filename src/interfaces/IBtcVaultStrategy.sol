// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IBtcVaultStrategy
 * @notice Interface for the BTC vault strategy managing multi-collateral assets
 */
interface IBtcVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralAdded(address indexed token, uint8 decimals);
    event CollateralRemoved(address indexed token);
    event LiquidityAdded(uint256 amount);
    event LiquidityRemoved(uint256 amount);
    event CollateralWithdrawn(address indexed token, uint256 amount, address indexed to);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetNotSupported();
    error AssetAlreadySupported();
    error InvalidDecimals();
    error InsufficientLiquidity();
    error UnauthorizedVault();
    error InvalidAmount();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new supported collateral token
     * @param token Address of the BTC collateral token
     * @param decimals Decimals of the token
     */
    function addCollateral(address token, uint8 decimals) external;

    /**
     * @notice Remove a supported collateral token
     * @param token Address of the collateral token to remove
     */
    function removeCollateral(address token) external;

    /**
     * @notice Check if an asset is supported
     * @param token Address of the token to check
     * @return Whether the token is supported
     */
    function isSupportedAsset(address token) external view returns (bool);

    /**
     * @notice Get list of all supported collateral tokens
     * @return Array of supported token addresses
     */
    function getSupportedCollaterals() external view returns (address[] memory);

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add sovaBTC liquidity for redemptions
     * @param amount Amount of sovaBTC to add
     */
    function addLiquidity(uint256 amount) external;

    /**
     * @notice Remove excess sovaBTC liquidity
     * @param amount Amount of sovaBTC to remove
     * @param to Address to send the sovaBTC
     */
    function removeLiquidity(uint256 amount, address to) external;

    /*//////////////////////////////////////////////////////////////
                        VAULT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw assets to a recipient (only callable by vault)
     * @param token Asset to withdraw (must be sovaBTC)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawTo(address token, address to, uint256 amount) external;

    /**
     * @notice Withdraw collateral to admin
     * @param token Collateral token to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdrawCollateral(address token, uint256 amount, address to) external;

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total assets value in sovaBTC terms
     * @return Total value of all collateral
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Get balance of a specific collateral token
     * @param token Address of the collateral token
     * @return Balance of the token held by strategy
     */
    function collateralBalance(address token) external view returns (uint256);

    /**
     * @notice Get available liquidity for redemptions
     * @return Amount of sovaBTC available
     */
    function availableLiquidity() external view returns (uint256);

    /**
     * @notice Get the vault address
     * @return Address of the vault
     */
    function getVault() external view returns (address);

    /**
     * @notice Set the vault address
     * @param vault New vault address
     */
    function setVault(address vault) external;
}
