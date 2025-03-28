// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {tRWA} from "../token/tRWA.sol";
import {ISubscriptionModule} from "../interfaces/ISubscriptionModule.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title BaseSubscriptionModule
 * @notice Base implementation for subscription modules
 * @dev Simple routing contract for underlying tokens
 */
abstract contract BaseSubscriptionModule is Ownable {
    error InvalidAddress();

    // Core properties
    tRWA public immutable token;

    /**
     * @notice Constructor for BaseSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     */
    constructor(address _token) {
        if (_token == address(0)) revert InvalidAddress();

        _initializeOwner(msg.sender);
        token = tRWA(_token);
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @dev Base implementation with 1:1 token minting ratio
     * @param _amount Amount being deposited
     */
    function deposit(uint256 _amount) external payable virtual override {
        // Mint tokens to subscriber (1:1 ratio)
        token.deposit(_amount, msg.sender);
    }
}