// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";

/**
 * @title ItRWA
 * @notice Interface for Tokenized Real World Asset (tRWA)
 * @dev Defines the interface with all events and errors for the tRWA contract
 *      This is an extension interface (does not duplicate ERC4626 methods)
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
    error CallbackFailed();
    error tRWAUnauthorized();
    error ControllerAlreadySet();

    // Logic contracts
    function strategy() external view returns (IStrategy);
    function rules() external view returns (IRules);

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