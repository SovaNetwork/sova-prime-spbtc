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

    // Logic contracts
    function strategy() external view returns (IStrategy);
    function rules() external view returns (IRules);
}