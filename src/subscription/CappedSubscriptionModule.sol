// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title CappedSubscriptionModule
 * @notice Subscription module with a maximum cap on total investments
 * @dev Extends BaseSubscriptionModule with cap enforcement using token total supply
 */
contract CappedSubscriptionModule is BaseSubscriptionModule {
    // Cap tracking
    uint256 public maxCap;

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

        // Call base implementation to handle token minting
        super.deposit(_subscriber, _amount);
    }

    /**
     * @notice Get the remaining capacity for investments
     * @return remainingCap Amount that can still be invested
     */
    function getRemainingCap() external view returns (uint256) {
        return maxCap - ERC20(token).totalSupply();
    }
}