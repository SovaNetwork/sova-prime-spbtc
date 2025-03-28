// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

/**
 * @title CappedSubscriptionModule
 * @notice Subscription module with a maximum cap on total investments
 * @dev Extends BaseSubscriptionModule with cap enforcement
 */
contract CappedSubscriptionModule is BaseSubscriptionModule {
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
     * @param _maxCap Maximum total investment cap
     */
    constructor(address _token, uint256 _maxCap) BaseSubscriptionModule(_token) {
        if (_maxCap == 0) revert InvalidCap();
        maxCap = _maxCap;
    }

    /**
     * @notice Update the maximum investment cap
     * @param _newCap New maximum cap
     */
    function updateCap(uint256 _newCap) external onlyOwner {
        if (_newCap < totalInvested) revert InvalidCap();
        maxCap = _newCap;
        emit CapUpdated(_newCap);
    }

    /**
     * @notice Process a deposit to subscribe to the fund with cap enforcement
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     */
    function deposit(address _subscriber, uint256 _amount) external payable override {
        // Check if the deposit would exceed the cap
        uint256 remainingCap = maxCap - totalInvested;
        if (_amount > remainingCap) {
            revert CapExceeded(_amount, remainingCap);
        }

        // Update the total invested amount
        totalInvested += _amount;

        // Call base implementation to handle token minting
        super.deposit(_subscriber, _amount);
    }

    /**
     * @notice Get the remaining capacity for investments
     * @return remainingCap Amount that can still be invested
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