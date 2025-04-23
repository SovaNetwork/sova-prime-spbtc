// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "../rules/BaseRules.sol";
import {SubscriptionRules} from "../rules/SubscriptionRules.sol";

/**
 * @title MockCappedSubscriptionRules
 * @notice Mock for subscription rules with cap functionality
 */
contract MockCappedSubscriptionRules is SubscriptionRules {
    uint256 public maxCap;
    uint256 public totalMinted;

    /**
     * @notice Constructor
     * @param _admin Administrator address
     * @param _maxCap Maximum total cap
     * @param _enforceApproval Whether to enforce approval
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _admin,
        uint256 _maxCap,
        bool _enforceApproval,
        bool _isOpen
    ) SubscriptionRules(_admin, _enforceApproval, _isOpen) {
        maxCap = _maxCap;
        totalMinted = 0;
    }

    /**
     * @notice Update the maximum investment cap
     * @param _newCap New maximum cap
     */
    function updateCap(uint256 _newCap) external {
        maxCap = _newCap;
    }

    /**
     * @notice Get remaining cap available
     * @return Amount still available under the cap
     */
    function remainingCap() public view returns (uint256) {
        return maxCap > totalMinted ? maxCap - totalMinted : 0;
    }

    /**
     * @notice Overrides the evaluateDeposit to add cap checking
     * @param token Address of the token
     * @param sender Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address token,
        address sender,
        uint256 assets,
        address receiver
    ) public override returns (RuleResult memory result) {
        // First check subscription status using parent implementation
        RuleResult memory baseResult = super.evaluateDeposit(token, sender, assets, receiver);
        if (!baseResult.approved) {
            return baseResult;
        }

        // For mocking purposes, we'll simplify by just counting assets
        // Increment the total minted
        uint256 newTotal = totalMinted + assets;
        
        // Check if the deposit would exceed the cap
        if (newTotal > maxCap) {
            return RuleResult({
                approved: false,
                reason: "Deposit exceeds remaining cap"
            });
        }
        
        // Record the new total
        totalMinted = newTotal;

        // All checks passed
        return RuleResult({
            approved: true,
            reason: ""
        });
    }
}