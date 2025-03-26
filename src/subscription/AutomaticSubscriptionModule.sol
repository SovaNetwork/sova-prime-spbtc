// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title AutomaticSubscriptionModule
 * @notice Subscription module that automatically processes deposits and issues tokens
 * @dev Extends BaseSubscriptionModule with immediate token issuance logic
 */
contract AutomaticSubscriptionModule is BaseSubscriptionModule {
    // Additional parameters for token issuance
    uint256 public tokenPriceInUSD; // Price per token in USD with 18 decimals precision

    // Events
    event TokenPriceUpdated(uint256 newPrice);

    // Errors
    error ZeroTokenPrice();
    error DepositFailed();

    /**
     * @notice Constructor for AutomaticSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        bool _isOpen
    ) BaseSubscriptionModule(_token, _treasury, _minSubscriptionAmount, _isOpen) {
        if (_tokenPriceInUSD == 0) revert ZeroTokenPrice();
        tokenPriceInUSD = _tokenPriceInUSD;
    }

    /**
     * @notice Update the token price
     * @param _newPrice New token price in USD (18 decimals)
     */
    function updateTokenPrice(uint256 _newPrice) external onlyAdmin {
        if (_newPrice == 0) revert ZeroTokenPrice();
        tokenPriceInUSD = _newPrice;
        emit TokenPriceUpdated(_newPrice);
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited in USD (18 decimals)
     * @return requestId Unique identifier for the subscription request (always processed immediately)
     */
    function deposit(address _subscriber, uint256 _amount) external payable virtual override returns (uint256) {
        _validateSubscription(_subscriber, _amount);

        // Create a subscription request
        uint256 requestId = _createSubscriptionRequest(_subscriber, _amount);

        // Calculate tokens to mint based on current token price
        uint256 tokensToMint = (_amount * 1e18) / tokenPriceInUSD;

        // Transfer funds to treasury
        // Note: In real implementation, this would handle the specifics of the asset being deposited
        // This example assumes USD stablecoins for simplicity

        // Update request status
        requests[requestId].status = SubscriptionStatus.PROCESSED;

        // Mint tokens to subscriber
        token.mint(_subscriber, tokensToMint);

        emit SubscriptionProcessed(requestId, _subscriber, _amount, tokensToMint);

        return requestId;
    }

    /**
     * @notice Calculate number of tokens for a given USD amount
     * @param _usdAmount Amount in USD (18 decimals)
     * @return tokenAmount Number of tokens to be minted
     */
    function calculateTokenAmount(uint256 _usdAmount) external view returns (uint256) {
        return (_usdAmount * 1e18) / tokenPriceInUSD;
    }
}