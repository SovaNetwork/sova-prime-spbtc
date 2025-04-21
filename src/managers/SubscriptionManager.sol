// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ISubscriptionManager} from "./ISubscriptionManager.sol";
import {tRWA} from "../token/tRWA.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {SubscriptionRules} from "../rules/SubscriptionRules.sol";

/**
 * @title SubscriptionManager
 * @notice Manages subscriptions for tRWA tokens
 * @dev Implements subscription management and recurring payments
 */
contract SubscriptionManager is ISubscriptionManager, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Roles
    uint256 public constant SUBSCRIPTION_ADMIN_ROLE = 1 << 0;
    uint256 public constant PAYMENT_PROCESSOR_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Core storage
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => mapping(uint256 => bool)) public userSubscriptions;
    mapping(address => uint256[]) public userSubscriptionsList;
    mapping(uint256 => address) public subscriptionOwner;

    // Counters
    uint256 private _nextSubscriptionId = 1;

    // Subscription rounds
    mapping(uint256 => SubscriptionRound) public subscriptionRounds;
    uint256 private _nextRoundId = 1;
    uint256 private _currentRoundId = 0;

    // Contract references
    address public immutable token;
    address public immutable asset;
    address public immutable strategy;
    address public immutable subRules; // SubscriptionRules contract

    // Fee settings
    address public feeRecipient;
    uint256 public subscriptionFee;
    uint256 public withdrawalFee;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param _token tRWA token address
     * @param _admin Administrator address
     * @param _subRules SubscriptionRules contract
     * @param _feeRecipient Fee recipient address
     * @param _subscriptionFee Fee for subscriptions in basis points (e.g., 100 = 1%)
     * @param _withdrawalFee Fee for withdrawals in basis points
     */
    constructor(
        address _token,
        address _admin,
        address _subRules,
        address _feeRecipient,
        uint256 _subscriptionFee,
        uint256 _withdrawalFee
    ) {
        if (_token == address(0) || _admin == address(0) || _subRules == address(0)) {
            revert InvalidAddress();
        }

        token = _token;
        strategy = tRWA(_token).strategy();
        asset = tRWA(_token).asset();
        subRules = _subRules;
        feeRecipient = _feeRecipient;
        subscriptionFee = _subscriptionFee;
        withdrawalFee = _withdrawalFee;

        _initializeOwner(_admin);
        _grantRoles(_admin, SUBSCRIPTION_ADMIN_ROLE | PAYMENT_PROCESSOR_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new subscription
     * @param user Address of the subscriber
     * @param amount Amount to deposit
     * @param frequency Frequency of recurring payments in seconds
     * @param metadata Additional subscription metadata
     * @return subscriptionId The ID of the created subscription
     */
    function createSubscription(
        address user,
        uint256 amount,
        uint256 frequency,
        bytes calldata metadata
    ) external returns (uint256 subscriptionId) {
        if (user == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (frequency < 1 days) revert InvalidFrequency();

        // Create subscription
        subscriptionId = _nextSubscriptionId++;
        uint256 nextPaymentDue = block.timestamp + frequency;

        subscriptions[subscriptionId] = Subscription({
            id: subscriptionId,
            user: user,
            amount: amount,
            frequency: frequency,
            nextPaymentDue: nextPaymentDue,
            active: true,
            metadata: metadata
        });

        // Register subscription for user
        userSubscriptions[user][subscriptionId] = true;
        userSubscriptionsList[user].push(subscriptionId);
        subscriptionOwner[subscriptionId] = user;

        // Add user to subscription rules allowlist
        SubscriptionRules(subRules).setSubscriber(user, true);

        emit SubscriptionCreated(subscriptionId, user, amount, frequency, metadata);
        return subscriptionId;
    }

    /**
     * @notice Cancel a subscription
     * @param subscriptionId ID of the subscription to cancel
     */
    function cancelSubscription(uint256 subscriptionId) external {
        Subscription storage sub = subscriptions[subscriptionId];
        
        // Check that caller is subscription owner
        if (sub.user != msg.sender && !hasAnyRole(msg.sender, SUBSCRIPTION_ADMIN_ROLE)) {
            revert Unauthorized();
        }

        if (!sub.active) revert InactiveSubscription();

        // Mark subscription as inactive
        sub.active = false;

        emit SubscriptionCancelled(subscriptionId, sub.user);
    }

    /**
     * @notice Process a subscription payment
     * @param subscriptionId ID of the subscription to process
     * @return success Whether the payment was processed successfully
     */
    function processPayment(
        uint256 subscriptionId
    ) external onlyRoles(PAYMENT_PROCESSOR_ROLE) returns (bool success) {
        Subscription storage sub = subscriptions[subscriptionId];

        if (!sub.active) revert InactiveSubscription();
        if (block.timestamp < sub.nextPaymentDue) revert PaymentNotDue();

        // Calculate fee
        uint256 fee = (sub.amount * subscriptionFee) / 10000;
        uint256 netAmount = sub.amount - fee;

        // Process deposit with fee
        address assetToken = asset;
        
        try SafeTransferLib.safeTransferFrom(assetToken, sub.user, address(this), sub.amount) {
            // Pay fee to fee recipient if configured
            if (fee > 0 && feeRecipient != address(0)) {
                SafeTransferLib.safeTransfer(assetToken, feeRecipient, fee);
            }

            // Transfer net amount to strategy
            SafeTransferLib.safeTransfer(assetToken, strategy, netAmount);

            // Update next payment due date
            sub.nextPaymentDue = block.timestamp + sub.frequency;

            emit PaymentProcessed(subscriptionId, sub.user, sub.amount, fee);
            return true;
        } catch {
            emit PaymentFailed(subscriptionId, sub.user, "Transfer failed");
            return false;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        // Validate parameters
        if (startTime >= endTime) revert InvalidTimeRange();
        if (startTime < block.timestamp) revert InvalidTimeRange();
        if (capacity == 0) revert InvalidCapacity();

        // Cannot open new round if one is active
        if (_currentRoundId != 0 && 
            subscriptionRounds[_currentRoundId].endTime > block.timestamp) {
            revert RoundAlreadyActive();
        }

        // Create new round
        roundId = _nextRoundId++;

        subscriptionRounds[roundId] = SubscriptionRound({
            id: roundId,
            name: name,
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            subscriptionCount: 0,
            active: true
        });

        // Set as current round
        _currentRoundId = roundId;

        // Enable subscriptions in the rules contract
        SubscriptionRules(subRules).setSubscriptionStatus(true);

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
        
        // Close subscriptions in the rules contract
        SubscriptionRules(subRules).setSubscriptionStatus(false);

        emit SubscriptionRoundClosed(_currentRoundId, round.subscriptionCount);
    }

    /**
     * @notice Update a user's subscription details
     * @param subscriptionId Subscription ID to update
     * @param amount New amount
     * @param frequency New frequency
     * @param metadata New metadata
     */
    function updateSubscription(
        uint256 subscriptionId,
        uint256 amount,
        uint256 frequency,
        bytes calldata metadata
    ) external onlyRoles(SUBSCRIPTION_ADMIN_ROLE) {
        Subscription storage sub = subscriptions[subscriptionId];
        
        if (!sub.active) revert InactiveSubscription();
        
        // Update subscription details
        if (amount > 0) sub.amount = amount;
        if (frequency > 0) sub.frequency = frequency;
        if (metadata.length > 0) sub.metadata = metadata;

        emit SubscriptionUpdated(subscriptionId, amount, frequency, metadata);
    }

    /**
     * @notice Update fee settings
     * @param _feeRecipient New fee recipient
     * @param _subscriptionFee New subscription fee
     * @param _withdrawalFee New withdrawal fee
     */
    function updateFees(
        address _feeRecipient,
        uint256 _subscriptionFee,
        uint256 _withdrawalFee
    ) external onlyOwner {
        // Fee recipient can be zero to disable fee collection
        feeRecipient = _feeRecipient;
        
        // Fees capped at 10%
        if (_subscriptionFee > 1000) revert FeeTooHigh();
        if (_withdrawalFee > 1000) revert FeeTooHigh();
        
        subscriptionFee = _subscriptionFee;
        withdrawalFee = _withdrawalFee;

        emit FeesUpdated(_feeRecipient, _subscriptionFee, _withdrawalFee);
    }

    /**
     * @notice Batch process multiple subscription payments
     * @param subscriptionIds Array of subscription IDs to process
     * @return successCount Number of successfully processed payments
     */
    function batchProcessPayments(
        uint256[] calldata subscriptionIds
    ) external onlyRoles(PAYMENT_PROCESSOR_ROLE) returns (uint256 successCount) {
        successCount = 0;
        
        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            try this.processPayment(subscriptionIds[i]) returns (bool success) {
                if (success) successCount++;
            } catch {
                // Continue processing other subscriptions
            }
        }

        return successCount;
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
     * @notice Check if a subscription payment is due
     * @param subscriptionId Subscription ID
     * @return isDue Whether payment is due
     * @return dueDate Next payment due date
     */
    function isPaymentDue(uint256 subscriptionId) external view returns (bool isDue, uint256 dueDate) {
        Subscription memory sub = subscriptions[subscriptionId];
        
        if (!sub.active) return (false, 0);
        
        return (block.timestamp >= sub.nextPaymentDue, sub.nextPaymentDue);
    }

    /**
     * @notice Check if an address has a specific role
     * @param user The address to check
     * @param role The role to check
     * @return hasRole Whether the address has the role
     */
    function hasRole(address user, uint256 role) public view returns (bool) {
        return OwnableRoles.hasRole(user, role);
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
        _revokeRoles(user, role);
    }
}