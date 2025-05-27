// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseReporter} from "./BaseReporter.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title AumOracleReporter
 * @notice A reporter contract that allows a trusted party to report the total AUM of the strategy
 */
contract AumOracleReporter is BaseReporter, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Current round number
    uint256 public currentRound;

    // The current fund aum
    uint256 public totalAssets;

    // The timestamp of the last update
    uint256 public lastUpdateAt;

    // Mapping of authorized updaters
    mapping(address => bool) public authorizedUpdaters;

    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/

    event AumUpdated(uint256 roundNumber, uint256 totalAssets, string source);
    event SetUpdater(address indexed updater, bool isAuthorized);

    // Errors
    error InvalidSource();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param initalAum Initial value to report
     */
    constructor(uint256 initialAum, address updater) {
        _initializeOwner(msg.sender);
        authorizedUpdaters[updater] = true;

        currentRound = 1;
        totalAssets = initialAum;
        lastUpdateAt = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update the reported value
     * @param price_ The new value to report
     * @param source_ The source of the price update
     */
    function update(uint256 price_, string calldata source_) external {
        if (!authorizedUpdaters[msg.sender]) revert Unauthorized();
        if (bytes(source_).length == 0) revert InvalidSource();

        // Create new price update
        currentRound++;
        totalAssets = totalAssets_;
        lastUpdateAt = block.timestamp;

        emit AumUpdated(currentRound, totalAssets, source_);
    }


    /**
     * @notice Report the current value
     * @return The encoded current value
     */
    function report() external view override returns (bytes memory) {
        return abi.encode(totalAssets);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set whether an address is authorized to update values
     * @param updater Address to modify authorization for
     * @param isAuthorized Whether the address should be authorized
     */
    function setUpdater(address updater, bool isAuthorized) external onlyOwner {
        authorizedUpdaters[updater] = isAuthorized;
        emit SetUpdater(updater, isAuthorized);
    }
}
