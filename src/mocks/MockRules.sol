// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "../rules/BaseRules.sol";

/**
 * @title MockRules
 * @notice A simple rules implementation for testing that allows full control over approval results
 */
contract MockRules is BaseRules {
    bool private _shouldApprove;
    string private _rejectReason;

    /**
     * @notice Constructor
     * @param initialApprove Initial approval state
     * @param rejectReason Message to return when rejected
     */
    constructor(bool initialApprove, string memory rejectReason) BaseRules("MockRules") {
        _shouldApprove = initialApprove;
        _rejectReason = rejectReason;
    }

    /**
     * @notice Set whether operations should be approved or rejected
     * @param shouldApprove Whether to approve operations
     * @param rejectReason Reason to provide when rejecting
     */
    function setApproveStatus(bool shouldApprove, string memory rejectReason) external {
        _shouldApprove = shouldApprove;
        _rejectReason = rejectReason;
    }

    /**
     * @notice Evaluate transfer operation
     * @return result Rule evaluation result
     */
    function evaluateTransfer(
        address,
        address,
        address,
        uint256
    ) public view override returns (RuleResult memory) {
        return RuleResult({
            approved: _shouldApprove,
            reason: _shouldApprove ? "" : _rejectReason
        });
    }

    /**
     * @notice Evaluate deposit operation
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address,
        address,
        uint256,
        address
    ) public view override returns (RuleResult memory) {
        return RuleResult({
            approved: _shouldApprove,
            reason: _shouldApprove ? "" : _rejectReason
        });
    }

    /**
     * @notice Evaluate withdraw operation
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address,
        address,
        uint256,
        address,
        address
    ) public view override returns (RuleResult memory) {
        return RuleResult({
            approved: _shouldApprove,
            reason: _shouldApprove ? "" : _rejectReason
        });
    }
}