// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BasicStrategy} from "./BasicStrategy.sol";
import {BaseReporter} from "../reporter/BaseReporter.sol";

/**
 * @title ReportedStrategy
 * @notice A strategy contract that reports its underlying asset balance through an external oracle
 */
contract ReportedStrategy is BasicStrategy {
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Optional cache for the last reported balance
    uint256 public lastReportedBalance;
    uint256 public lastReportTimestamp;

    // The reporter contract
    BaseReporter public reporter;

    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/

    // Errors
    error InvalidReporter();

    // Events
    event SetReporter(address indexed reporter);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param admin_ The admin address
     * @param manager_ The manager address
     * @param asset_ The asset address
     * @param reporter_ The reporter contract
     */
    constructor(
        address admin_,
        address manager_,
        address asset_,
        address reporter_
    ) BasicStrategy(admin_, manager_, asset_) {
        if (reporter_ == address(0)) revert InvalidReporter();
        reporter = BaseReporter(reporter_);
    }

    /*//////////////////////////////////////////////////////////////
                            STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
