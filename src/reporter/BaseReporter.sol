// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title BaseReporter
 * @notice Abstract base contract for reporters that return strategy info
 */
abstract contract BaseReporter {
    /**
     * @notice Report the current value of an asset
     * @return the content of the report
     */
    function report() external view virtual returns (bytes memory);
}
