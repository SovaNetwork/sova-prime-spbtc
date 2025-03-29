// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseReporter} from "./BaseReporter.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title PriceOracleReporter
 * @notice A reporter contract that allows a trusted party to update a price value
 */
contract PriceOracleReporter is BaseReporter, Ownable {
    // Maximum allowed percentage deviation (denominated in basis points, 10000 = 100%)
    uint256 public maxDeviationBps = 500; // Default 5% max deviation

    // Current round number
    uint256 public currentRound;

    // The current price
    uint256 public price;

    // The timestamp of the last price update
    uint256 public lastPriceAt;

    // Mapping of authorized updaters
    mapping(address => bool) public authorizedUpdaters;

    // Events
    event PriceUpdated(uint256 roundNumber, uint256 price, string source);
    event SetUpdater(address indexed updater, bool isAuthorized);
    event SetMaxDeviation(uint256 newMaxDeviationBps);

    // Errors
    error Unauthorized();
    error InvalidSource();
    error MaxDeviation();

    /**
     * @notice Contract constructor
     * @param initialValue Initial value to report
     */
    constructor(uint256 initialValue, address updater) {
        _initializeOwner(msg.sender);
        authorizedUpdaters[updater] = true;

        currentRound = 1;
        price = initialValue;
        lastPriceAt = block.timestamp;
    }

    /**
     * @notice Update the reported value
     * @param newValue The new value to report
     */
    function update(uint256 price_, string calldata source_) external {
        if (!authorizedUpdaters[msg.sender]) revert Unauthorized();
        if (bytes(source_).length == 0) revert InvalidSource();

        // Check deviation from last price if this isn't the first update
        if (lastPriceAt > 0) {
            // Calculate percentage deviation in basis points (10000 = 100%)
            uint256 deviationBps;
            if (price_ > price) {
                deviationBps = ((price_ - price) * 10000) / price;
            } else {
                deviationBps = ((price - price_) * 10000) / price;
            }

            // Check if deviation exceeds maximum allowed
            if (deviationBps > maxDeviationBps) revert MaxDeviation();
        }

        // Create new price update
        currentRound++;
        price = price_;
        lastPriceAt = block.timestamp;

        emit PriceUpdated(currentRound, price, source_);
    }


    /**
     * @notice Report the current value
     * @return The encoded current value
     */
    function report() external view override returns (bytes memory) {
        return abi.encode(price);
    }

    /**
     * @notice Set whether an address is authorized to update values
     * @param updater Address to modify authorization for
     * @param isAuthorized Whether the address should be authorized
     */
    function setUpdater(address updater, bool isAuthorized) external onlyOwner {
        authorizedUpdaters[updater] = isAuthorized;
        emit SetUpdater(updater, isAuthorized);
    }

    /**
     * @notice Set the maximum allowed deviation between price updates in basis points
     * @param newMaxDeviationBps The new maximum deviation in basis points (10000 = 100%)
     */
    function setMaxDeviation(uint256 newMaxDeviationBps) external onlyOwner {
        maxDeviationBps = newMaxDeviationBps;
        emit SetMaxDeviation(newMaxDeviationBps);
    }
}
