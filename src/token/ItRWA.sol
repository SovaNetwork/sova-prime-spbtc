// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";

/**
 * @title ItRWA
 * @notice Interface for Tokenized Real World Asset (tRWA)
 * @dev Defines the interface with all events and errors for the tRWA contract
 */
interface ItRWA {
    // Configuration struct for deployment
    struct ConfigurationStruct {
        // The strategy contract
        IStrategy strategy;

        // The rules contract
        IRules rules;
    }

    // Errors
    error InvalidAddress();
    error AssetMismatch();
    error RuleCheckFailed(string reason);
    error WithdrawMoreThanMax();
    error Unauthorized();
    error CallbackFailed();
    error DepositMoreThanMax();
    error MintMoreThanMax();
    error RedeemMoreThanMax();

    // Logic contracts
    function strategy() external view returns (IStrategy);
    function rules() external view returns (IRules);
    
    // ERC4626 methods
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function maxDeposit(address) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function maxMint(address) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    
    // ERC20 methods required for ERC4626
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // Callback-enabled operations
    function deposit(
        uint256 assets, 
        address receiver,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 shares);
    
    function mint(
        uint256 shares, 
        address receiver,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 assets);
    
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 shares);
    
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 assets);

    /**
     * @notice Utility function to burn tokens
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external;
}