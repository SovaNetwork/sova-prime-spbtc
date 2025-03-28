// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ApprovalSubscriptionModule} from "./ApprovalSubscriptionModule.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title CappedApprovalSubscriptionModule
 * @notice Subscription module that requires admin approval and enforces a maximum cap
 * @dev Extends ApprovalSubscriptionModule with cap enforcement
 */
contract CappedApprovalSubscriptionModule is ApprovalSubscriptionModule {
    // Cap tracking
    uint256 public maxCap;

    // Events
    event CapUpdated(uint256 newCap);

    // Errors
    error CapExceeded(uint256 requested, uint256 remaining);
    error InvalidCap();

    /**
     * @notice Constructor for CappedApprovalSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     * @param _maxCap Maximum total investment cap
     */
    constructor(
        address _token,
        uint256 _maxCap
    ) ApprovalSubscriptionModule(_token) {
        if (_maxCap == 0) revert InvalidCap();
        maxCap = _maxCap;
    }

    /**
     * @notice Update the maximum investment cap
     * @param _newCap New maximum cap
     */
    function updateCap(uint256 _newCap) external onlyOwner {
        if (_newCap < ERC20(token).totalSupply()) revert InvalidCap();
        maxCap = _newCap;
        emit CapUpdated(_newCap);
    }

    /**
     * @notice Process a deposit to subscribe to the fund with cap enforcement
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     */
    function deposit(address _subscriber, uint256 _amount) external payable override {
        // Check if the deposit would exceed the cap using current total supply
        uint256 currentSupply = ERC20(token).totalSupply();
        uint256 remainingCap = maxCap - currentSupply;
        if (_amount > remainingCap) {
            revert CapExceeded(_amount, remainingCap);
        }

        // Call parent implementation to handle approval checks and pending deposits
        super.deposit(_subscriber, _amount);
    }

    /**
     * @notice Get the remaining capacity for investments
     * @return remainingCap Amount that can still be invested
     */
    function getRemainingCap() external view returns (uint256) {
        return maxCap - ERC20(token).totalSupply();
    }

    /**
     * @notice Get the percentage of the cap that has been filled
     * @return percentage Percentage filled (0-100) with 2 decimal precision (e.g., 8756 = 87.56%)
     */
    function getCapFillPercentage() external view returns (uint256) {
        return (ERC20(token).totalSupply() * 10000) / maxCap;
    }
}