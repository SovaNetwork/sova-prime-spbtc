// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";

import {SubscriptionRules} from "./SubscriptionRules.sol";
import {ItRWA} from "../token/ItRWA.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title CappedSubscriptionRules
 * @notice Rule implementation that restricts deposits based on subscription status and caps
 * @dev Extends SubscriptionRules with investment caps that track total mints, not affected by burns
 */
contract CappedSubscriptionRules is SubscriptionRules {
    // Cap tracking
    uint256 public maxCap;
    uint256 public totalMinted;

    // Events
    event CapUpdated(uint256 newCap);
    event TokensMinted(address indexed user, uint256 amount);

    // Errors
    error CapExceeded(uint256 requested, uint256 remaining);
    error InvalidCap();

    /**
     * @notice Constructor for CappedSubscriptionRules
     * @param _admin Address that will have admin rights
     * @param _maxCap Maximum total investment cap
     * @param _enforceApproval Whether to enforce subscriber approval
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _admin,
        uint256 _maxCap,
        bool _enforceApproval,
        bool _isOpen
    ) SubscriptionRules(_admin, _enforceApproval, _isOpen) {
        if (_maxCap == 0) revert InvalidCap();
        maxCap = _maxCap;
        totalMinted = 0;
    }

    /**
     * @notice Update the maximum investment cap
     * @param _newCap New maximum cap
     */
    function updateCap(uint256 _newCap) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        if (_newCap < totalMinted) revert InvalidCap();
        maxCap = _newCap;
        emit CapUpdated(_newCap);
    }

    /**
     * @notice Get remaining cap available
     * @return Amount still available under the cap
     */
    function remainingCap() public view returns (uint256) {
        return maxCap > totalMinted ? maxCap - totalMinted : 0;
    }

    /**
     * @notice Evaluates a deposit according to subscription rules and cap limits
     * @param token Address of the tRWA token
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address token,
        address user,
        uint256 assets,
        address receiver
    ) public override returns (RuleResult memory result) {
        // First check subscription status using parent implementation
        RuleResult memory baseResult = super.evaluateDeposit(token, user, assets, receiver);
        if (!baseResult.approved) {
            return baseResult;
        }

        // Check if the deposit would exceed the cap
        uint256 available = remainingCap();

        // Increment the total minted
        totalMinted += tRWA(token).convertToShares(assets);

        if (totalMinted > maxCap) {
            return RuleResult({
                approved: false,
                reason: string(abi.encodePacked(
                    "Deposit exceeds remaining cap (requested: ",
                    _toString(assets),
                    ", remaining: ",
                    _toString(available),
                    ")"
                ))
            });
        }

        // All checks passed
        return RuleResult({
            approved: true,
            reason: ""
        });
    }

    /**
     * @dev Utility function to convert uint256 to string
     * @param value Number to convert
     * @return String representation
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // Handle zero case
        if (value == 0) {
            return "0";
        }

        // Find length of number
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        // Allocate string
        bytes memory buffer = new bytes(digits);

        // Fill string from right to left
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}