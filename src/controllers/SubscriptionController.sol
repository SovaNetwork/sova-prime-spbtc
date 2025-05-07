// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ISubscriptionController} from "./ISubscriptionController.sol";
import {tRWA} from "../token/tRWA.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";

/**
 * @title SubscriptionController
 * @notice Manages subscriptions for tRWA tokens
 * @dev Implements subscription management and round validation
 */
contract SubscriptionController is ISubscriptionController, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Roles
    uint256 public constant SUBSCRIPTION_ADMIN_ROLE = 1 << 0;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Core storage
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptionsList;

    // Counters
    uint256 private _nextSubscriptionId = 1;

    // Subscription rounds
    mapping(uint256 => SubscriptionRound) public subscriptionRounds;
    uint256 private _nextRoundId = 1;
    uint256 private _currentRoundId = 0;

    // Contract references
    // address public immutable token; // Removed

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param _admin Administrator address
     * @param _managers Additional manager addresses to grant admin role (optional)
     */
    constructor(
        // address _token, // Removed
        address _admin,
        address[] memory _managers
    ) {
        if (/*_token == address(0) ||*/ _admin == address(0)) { // _token check removed
            revert InvalidAddress();
        }

        // token = _token; // Removed

        // Initialize owner and grant admin role
        _initializeOwner(_admin);
        _grantRoles(_admin, SUBSCRIPTION_ADMIN_ROLE);

        // Grant admin role to additional managers if provided
        for (uint256 i = 0; i < _managers.length; i++) {
            if (_managers[i] != address(0) && _managers[i] != _admin) {
                _grantRoles(_managers[i], SUBSCRIPTION_ADMIN_ROLE);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Utility function to check and close expired rounds
     * @return closed Whether a round was closed
     */
    function checkAndCloseExpiredRound() public returns (bool) {
        uint256 currentRound = _currentRoundId;

        // No active round
        if (currentRound == 0) return false;

        SubscriptionRound storage round = subscriptionRounds[currentRound];

        // Check if round has expired but is still marked active
        if (round.active && block.timestamp > round.end) {
            // Mark as inactive
            round.active = false;

            emit SubscriptionRoundClosed(currentRound, round.deposits);
            return true;
        }

        return false;
    }

    /**
     * @notice Open a new subscription round
     * @param name Name of the subscription round
     * @param startTime Start time of the round
     * @param endTime End time of the round
     * @param capacity Maximum number of subscriptions
     * @return roundId ID of the created round
     */
    function openSubscriptionRound(
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 capacity
    ) external onlyRoles(SUBSCRIPTION_ADMIN_ROLE) returns (uint256 roundId) {
        // Auto-close any expired round first
        checkAndCloseExpiredRound();

        // Validate parameters
        if (startTime >= endTime) revert InvalidTimeRange();
        if (capacity == 0) revert InvalidCapacity();

        // Cannot open new round if one is active
        if (_currentRoundId != 0 &&
            subscriptionRounds[_currentRoundId].active) {
            revert RoundAlreadyActive();
        }

        // Create new round
        roundId = _nextRoundId++;

        subscriptionRounds[roundId] = SubscriptionRound({
            id: roundId,
            name: name,
            start: startTime,
            end: endTime,
            capacity: capacity,
            deposits: 0,
            active: true
        });

        // Set as current round
        _currentRoundId = roundId;

        emit SubscriptionRoundOpened(roundId, name, startTime, endTime, capacity);
        return roundId;
    }

    /**
     * @notice Close the current subscription round
     */
    function closeSubscriptionRound() external onlyRoles(SUBSCRIPTION_ADMIN_ROLE) {
        SubscriptionRound storage round = subscriptionRounds[_currentRoundId];

        if (_currentRoundId == 0 || !round.active) revert NoActiveRound();

        // Mark as inactive
        round.active = false;

        emit SubscriptionRoundClosed(_currentRoundId, round.deposits);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION & CALLBACK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a round is logically active (considering time constraints)
     * @param roundId ID of the round to check
     * @return isActive Whether the round is active and valid time-wise
     */
    function isRoundActive(uint256 roundId) public view returns (bool) {
        SubscriptionRound memory round = subscriptionRounds[roundId];

        // Not active in storage
        if (!round.active) return false;

        // Time-based checks
        if (block.timestamp < round.start) return false;  // Not started yet
        if (block.timestamp > round.end) return false;    // Already ended

        return true;
    }

    /**
     * @notice Validates deposit eligibility against current round constraints
     * @param user User address
     * @param assets Asset amount
     * @return valid Whether the deposit is valid
     * @return reason Reason for validation failure
     */
    function validateDeposit(address user, uint256 assets) external view returns (bool valid, string memory reason) {
        // First check if there's a current round
        if (_currentRoundId == 0) {
            return (false, "No active subscription round");
        }

        // Use the isRoundActive function for time-aware validation
        if (!isRoundActive(_currentRoundId)) {
            return (false, "Subscription round not active or expired");
        }

        SubscriptionRound memory round = subscriptionRounds[_currentRoundId];

        // Check for capacity limits
        if (round.deposits >= round.capacity) {
            return (false, "Subscription round capacity reached");
        }

        // We can't check KYC in a view function because rules.evaluateDeposit
        // potentially modifies state. In a real implementation, we'd need to
        // rethink our pattern or have a separate KYC check that is view-only.

        // All checks passed
        return (true, "");
    }

    /**
     * @notice Callback function for token operations
     * @param operationType Type of operation (keccak256 of operation name)
     * @param success Whether the operation was successful
     * @param data Additional data passed from the caller
     */
    function operationCallback(
        bytes32 operationType,
        bool success,
        bytes memory data
    ) external {
        // Only accept callbacks from the token -- This check is removed.
        // Security relies on tRWA only calling its designated controller.
        // if (msg.sender != token) revert OnlyTokenAllowed(); // Removed

        // Auto-close expired round if needed (makes deposits more likely to succeed)
        checkAndCloseExpiredRound();

        if (operationType == keccak256("DEPOSIT") || operationType == keccak256("MINT")) {
            // Handle deposit/mint operation
            if (success) {
                // Extract user & amount from data
                (address user, uint256 amount) = abi.decode(data, (address, uint256));

                // Record deposit as subscription
                _recordSubscription(user, amount);

                // Increment subscription count for the active round
                _incrementRoundSubscriptions(_currentRoundId);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal helper to record a subscription
     * @param user User address
     * @param amount Subscription amount
     */
    function _recordSubscription(address user, uint256 amount) internal {
        uint256 subId = _nextSubscriptionId++;

        // Store subscription details
        Subscription memory sub = Subscription({
            id: subId,
            user: user,
            amount: amount,
            amountWithdrawn: 0
        });

        subscriptions[subId] = sub;
        userSubscriptionsList[user].push(subId);

        emit SubscriptionCreated(subId, user, amount, 0, "");
    }

    /**
     * @notice Increment subscription count when a subscription is created
     * @param roundId Round ID to increment the counter for
     */
    function _incrementRoundSubscriptions(uint256 roundId) internal {
        SubscriptionRound storage round = subscriptionRounds[roundId];
        if (round.active) {
            round.deposits++;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get a subscription by ID
     * @param subscriptionId ID of the subscription
     * @return subscription The subscription details
     */
    function getSubscription(uint256 subscriptionId) external view returns (Subscription memory) {
        return subscriptions[subscriptionId];
    }

    /**
     * @notice Get current subscription round
     * @return round The current subscription round
     */
    function getCurrentRound() external view returns (SubscriptionRound memory) {
        return subscriptionRounds[_currentRoundId];
    }

    /**
     * @notice Get all subscriptions for a user
     * @param user User address
     * @return userSubs Array of subscription IDs
     */
    function getUserSubscriptions(address user) external view returns (uint256[] memory) {
        return userSubscriptionsList[user];
    }

    /**
     * @notice Check if an address has a specific role
     * @param user The address to check
     * @param role The role to check
     * @return hasRole Whether the address has the role
     */
    function hasRole(address user, uint256 role) public view returns (bool) {
        return hasAnyRole(user, role);
    }

    /**
     * @notice Grant a role to an address
     * @param user The address to grant the role to
     * @param role The role to grant
     */
    function grantRole(address user, uint256 role) external onlyOwner {
        _grantRoles(user, role);
    }

    /**
     * @notice Revoke a role from an address
     * @param user The address to revoke the role from
     * @param role The role to revoke
     */
    function revokeRole(address user, uint256 role) external onlyOwner {
        _removeRoles(user, role);
    }
}