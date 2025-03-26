// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AutomaticSubscriptionModule} from "./AutomaticSubscriptionModule.sol";

/**
 * @title CappedSubscriptionModule
 * @notice Subscription module with a maximum cap on total investments
 * @dev Extends AutomaticSubscriptionModule with cap enforcement
 */
contract CappedSubscriptionModule is AutomaticSubscriptionModule {
    // Cap tracking
    uint256 public maxCap;
    uint256 public totalInvested;

    // Events
    event CapUpdated(uint256 newCap);

    // Errors
    error CapExceeded(uint256 requested, uint256 remaining);
    error InvalidCap();

    /**
     * @notice Constructor for CappedSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _maxCap Maximum total investment cap in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        uint256 _maxCap,
        bool _isOpen
    ) AutomaticSubscriptionModule(
        _token,
        _treasury,
        _minSubscriptionAmount,
        _tokenPriceInUSD,
        _isOpen
    ) {
        if (_maxCap == 0) revert InvalidCap();
        maxCap = _maxCap;
    }

    /**
     * @notice Update the maximum investment cap
     * @param _newCap New maximum cap in USD (18 decimals)
     */
    function updateCap(uint256 _newCap) external onlyAdmin {
        if (_newCap < totalInvested) revert InvalidCap();
        maxCap = _newCap;
        emit CapUpdated(_newCap);
    }

    /**
     * @notice Process a deposit to subscribe to the fund with cap enforcement
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited in USD (18 decimals)
     * @return requestId Unique identifier for the subscription request
     */
    function deposit(address _subscriber, uint256 _amount) external payable override returns (uint256) {
        _validateSubscription(_subscriber, _amount);

        // Check if the deposit would exceed the cap
        uint256 remainingCap = maxCap - totalInvested;
        if (_amount > remainingCap) {
            revert CapExceeded(_amount, remainingCap);
        }

        // Create a subscription request
        uint256 requestId = _createSubscriptionRequest(_subscriber, _amount);

        // Calculate tokens to mint based on current token price
        uint256 tokensToMint = (_amount * 1e18) / tokenPriceInUSD;

        // Update the total invested amount
        totalInvested += _amount;

        // Update request status
        requests[requestId].status = SubscriptionStatus.PROCESSED;

        // Mint tokens to subscriber
        token.mint(_subscriber, tokensToMint);

        emit SubscriptionProcessed(requestId, _subscriber, _amount, tokensToMint);

        return requestId;
    }

    /**
     * @notice Get the remaining capacity for investments
     * @return remainingCap Amount in USD (18 decimals) that can still be invested
     */
    function getRemainingCap() external view returns (uint256) {
        return maxCap - totalInvested;
    }

    /**
     * @notice Get the percentage of the cap that has been filled
     * @return percentage Percentage filled (0-100) with 2 decimal precision (e.g., 8756 = 87.56%)
     */
    function getCapFillPercentage() external view returns (uint256) {
        return (totalInvested * 10000) / maxCap;
    }
}