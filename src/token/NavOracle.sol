// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title NavOracle
 * @notice Oracle contract for updating underlying value per token in tRWA tokens
 * @dev This is a simplified oracle. In production, you would want more security measures
 */
contract NavOracle is Ownable {
    mapping(address => bool) public authorizedUpdaters;

    // The token this oracle is tied to
    tRWA public immutable token;

    // Maximum allowed percentage deviation (denominated in basis points, 10000 = 100%)
    uint256 public maxDeviationBps = 500; // Default 5% max deviation

    // Price update metadata structure
    struct PriceUpdate {
        uint256 roundNumber;
        uint256 price;        // Underlying value per token in USD (18 decimals)
        uint256 timestamp;    // Block timestamp when the update was recorded
        string source;        // Source of the price data
    }

    // Price update history
    PriceUpdate[] private priceUpdateHistory;

    // Latest price update
    PriceUpdate public latestPriceUpdate;

    // Current round number
    uint256 public currentRound;

    // Events
    event UnderlyingValueUpdated(
        uint256 roundNumber,
        uint256 price,
        uint256 timestamp,
        string source
    );
    event UpdaterStatusChanged(address indexed updater, bool isAuthorized);
    event MaxDeviationUpdated(uint256 oldMaxDeviationBps, uint256 newMaxDeviationBps);

    // Errors
    error InvalidUnderlyingValue();
    error InvalidAddress();
    error DeviationTooLarge();
    error InvalidDeviation();
    error InvalidRoundNumber();
    error InvalidSource();
    error InvalidToken();

    /**
     * @notice Contract constructor
     * @param _token Address of the tRWA token this oracle is tied to
     * @param _initialPrice Initial price value in USD (18 decimals)
     */
    constructor(address _token, uint256 _initialPrice) {
        if (_token == address(0)) revert InvalidAddress();
        if (_initialPrice == 0) revert InvalidUnderlyingValue();

        _initializeOwner(msg.sender);
        authorizedUpdaters[msg.sender] = true;
        token = tRWA(_token);

        // Set initial price
        if (_initialPrice > 0) {
            // Create initial price update
            PriceUpdate memory initialUpdate = PriceUpdate({
                roundNumber: 1,
                price: _initialPrice,
                timestamp: block.timestamp,
                source: "Deployment"
            });

            // Store the initial update
            latestPriceUpdate = initialUpdate;
            priceUpdateHistory.push(initialUpdate);
            currentRound = 1;

            // Update token with initial price
            token.updateUnderlyingValue(_initialPrice);

            emit UnderlyingValueUpdated(1, _initialPrice, block.timestamp, "Deployment");
        }
    }

    /**
     * @notice Modifier to restrict function calls to authorized updaters
     */
    modifier onlyAuthorizedUpdater() {
        if (!authorizedUpdaters[msg.sender]) revert Unauthorized();
        _;
    }

    /**
     * @notice Update the underlying value per token
     * @param _price New underlying value per token in USD (18 decimals)
     * @param _source Source of the price data
     */
    function updateUnderlyingValue(
        uint256 _price,
        string calldata _source
    ) external onlyAuthorizedUpdater {
        if (_price == 0) revert InvalidUnderlyingValue();
        if (bytes(_source).length == 0) revert InvalidSource();

        // Check deviation from last price if this isn't the first update
        if (latestPriceUpdate.timestamp > 0) {
            // Calculate percentage deviation in basis points (10000 = 100%)
            uint256 deviationBps;
            if (_price > latestPriceUpdate.price) {
                deviationBps = ((_price - latestPriceUpdate.price) * 10000) / latestPriceUpdate.price;
            } else {
                deviationBps = ((latestPriceUpdate.price - _price) * 10000) / latestPriceUpdate.price;
            }

            // Check if deviation exceeds maximum allowed
            if (deviationBps > maxDeviationBps) revert DeviationTooLarge();
        }

        // Increment round number
        uint256 roundNumber = currentRound + 1;
        currentRound = roundNumber;

        // Create new price update
        PriceUpdate memory newUpdate = PriceUpdate({
            roundNumber: roundNumber,
            price: _price,
            timestamp: block.timestamp,
            source: _source
        });

        // Store the update
        latestPriceUpdate = newUpdate;
        priceUpdateHistory.push(newUpdate);

        // Update the token with the new price
        token.updateUnderlyingValue(_price);

        emit UnderlyingValueUpdated(roundNumber, _price, block.timestamp, _source);
    }

    /**
     * @notice Get the price update at a specific round number
     * @param _roundNumber Round number to retrieve
     * @return PriceUpdate struct containing the requested price update
     */
    function getPriceUpdateAtRound(uint256 _roundNumber) external view returns (PriceUpdate memory) {
        if (_roundNumber == 0 || _roundNumber > currentRound) revert InvalidRoundNumber();

        // If accessing the history array is expensive, consider storing a mapping from round number to update instead
        // This is simplified for demonstration purposes
        for (uint256 i = 0; i < priceUpdateHistory.length; i++) {
            if (priceUpdateHistory[i].roundNumber == _roundNumber) {
                return priceUpdateHistory[i];
            }
        }

        revert InvalidRoundNumber();
    }

    /**
     * @notice Get the latest price update
     * @return The latest price update
     */
    function getLatestPriceUpdate() external view returns (PriceUpdate memory) {
        if (latestPriceUpdate.timestamp == 0) revert InvalidUnderlyingValue();
        return latestPriceUpdate;
    }

    /**
     * @notice Add or remove an authorized updater
     * @param _updater Address of the updater
     * @param _isAuthorized Whether the address is authorized
     */
    function setUpdaterStatus(address _updater, bool _isAuthorized) external onlyOwner {
        if (_updater == address(0)) revert InvalidAddress();

        authorizedUpdaters[_updater] = _isAuthorized;

        emit UpdaterStatusChanged(_updater, _isAuthorized);
    }

    /**
     * @notice Update the maximum allowed deviation in basis points
     * @param _newMaxDeviationBps New maximum deviation (10000 = 100%)
     */
    function updateMaxDeviation(uint256 _newMaxDeviationBps) external onlyOwner {
        if (_newMaxDeviationBps == 0 || _newMaxDeviationBps > 5000) revert InvalidDeviation();

        uint256 oldMaxDeviationBps = maxDeviationBps;
        maxDeviationBps = _newMaxDeviationBps;

        emit MaxDeviationUpdated(oldMaxDeviationBps, _newMaxDeviationBps);
    }
}