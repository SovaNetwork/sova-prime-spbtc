// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC4626} from "forge-std/interfaces/IERC4626.sol";

/**
 * @title IBtcVaultShareToken
 * @notice Interface for the multi-collateral BTC vault share token
 */
interface IBtcVaultShareToken is IERC4626 {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(
        address indexed depositor, address indexed token, uint256 amount, uint256 shares, address indexed receiver
    );

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenNotSupported();
    error InsufficientAmount();
    error ZeroShares();
    error Paused();
    error InvalidStrategy();
    error StandardDepositDisabled();

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit BTC collateral tokens for shares
     * @param token Address of the BTC collateral token
     * @param amount Amount of collateral to deposit
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted
     */
    function depositCollateral(address token, uint256 amount, address receiver) external returns (uint256 shares);

    /**
     * @notice Preview shares for collateral deposit
     * @param token Address of the BTC collateral token
     * @param amount Amount of collateral to deposit
     * @return shares Amount of shares that would be minted
     */
    function previewDepositCollateral(address token, uint256 amount) external view returns (uint256 shares);

    /**
     * @notice Pause the vault
     */
    function pause() external;

    /**
     * @notice Unpause the vault
     */
    function unpause() external;

    /**
     * @notice Check if the vault is paused
     * @return Whether the vault is paused
     */
    function paused() external view returns (bool);
}
