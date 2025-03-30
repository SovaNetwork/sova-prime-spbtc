// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IRules} from "../interfaces/IRules.sol";
import {IRulesEngine} from "../interfaces/IRulesEngine.sol";

/**
 * @title BaseRules
 * @notice Base implementation of the IRules interface
 * @dev Abstract contract that implements shared functionality for all rules
 */
abstract contract BaseRules is IRules {
    // Rule metadata
    bytes32 public immutable ruleId;
    string public ruleName;

    /**
     * @notice Constructor
     * @param name_ Human readable name of the rule
     */
    constructor(string memory name_) {
        ruleName = name_;
        ruleId = keccak256(abi.encodePacked(address(this), name_));
    }

    /**
     * @notice Returns the bitmap of operations this rule applies to
     * @return Bitmap of operations
     */
    function appliesTo() external view virtual override returns (uint256) {
        // By default, rule applies to all operations
        return type(uint256).max;
    }

    /**
     * @notice Default transfer rule implementation
     * @dev Returns approved by default, override in child contracts
     */
    function evaluateTransfer(
        address,
        address,
        address,
        uint256
    ) external view virtual override returns (RuleResult memory) {
        return RuleResult({ approved: true, reason: "" });
    }

    /**
     * @notice Default deposit rule implementation
     * @dev Returns approved by default, override in child contracts
     */
    function evaluateDeposit(
        address,
        address,
        uint256,
        address
    ) external view virtual override returns (RuleResult memory) {
        return RuleResult({ approved: true, reason: "" });
    }

    /**
     * @notice Default withdraw rule implementation
     * @dev Returns approved by default, override in child contracts
     */
    function evaluateWithdraw(
        address,
        address,
        uint256,
        address,
        address
    ) external view virtual override returns (RuleResult memory) {
        return RuleResult({ approved: true, reason: "" });
    }
}