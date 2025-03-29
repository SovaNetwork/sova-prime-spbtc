// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BasicStrategy} from "./BasicStrategy.sol";
import {BaseReporter} from "../reporter/BaseReporter.sol";

/**
 * @title ReportedStrategy
 * @notice A strategy contract that reports its underlying asset balance through an external oracle
 */
contract ReportedStrategy is BasicStrategy {
    // The reporter contract
    BaseReporter public reporter;

    // Errors
    error InvalidReporter();

    // Events
    event SetReporter(address indexed reporter);

    /**
     * @notice Constructor
     * @param _reporter The reporter contract
     */
    constructor(address _reporter) {
        if (_reporter == address(0)) revert InvalidReporter();
        reporter = BaseReporter(_reporter);
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view override returns (uint256) {
        return abi.decode(reporter.report(), (uint256));
    }

    /**
     * @notice Set the reporter contract
     * @param _reporter The new reporter contract
     */
    function setReporter(address _reporter) external onlyManager() {
        if (_reporter == address(0)) revert InvalidReporter();

        reporter = BaseReporter(_reporter);

        emit SetReporter(_reporter);
    }
}
