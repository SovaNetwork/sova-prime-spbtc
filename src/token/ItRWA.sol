// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";

/**
 * @title ItRWA
 * @notice Interface for Tokenized Real World Asset (tRWA)
 * @dev Defines the interface with all events and errors for the tRWA contract
 *      This is an extension interface (does not duplicate ERC4626 methods)
 */
interface ItRWA {

    // Errors
    error InvalidAddress();
    error AssetMismatch();
    error RuleCheckFailed(string reason);

    // Logic contracts
    function strategy() external view returns (address);

    // Returns the address of the underlying asset
    function asset() external view returns (address);

    // Note: Standard ERC4626 operations are defined in the ERC4626 interface
    // and are not redefined here to avoid conflicts
}