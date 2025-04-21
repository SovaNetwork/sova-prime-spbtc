// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ISubscriptionManager
 * @notice Interface for subscription management
 * @dev Defines subscription management functionality and data structures
 */
interface ISubscriptionManager {
    // Structs
    struct Subscription {
        uint256 id;               // Unique identifier
        address user;             // Subscriber address
        uint256 amount;           // Payment amount
        uint256 frequency;        // Payment frequency in seconds
        uint256 nextPaymentDue;   // Next payment timestamp
        bool active;              // Whether subscription is active
        bytes metadata;           // Additional subscription data
    }

    struct SubscriptionRound {
        uint256 id;               // Unique identifier
        string name;              // Round name
        uint256 startTime;        // Start timestamp
        uint256 endTime;          // End timestamp
        uint256 capacity;         // Maximum subscription count
        uint256 subscriptionCount; // Current subscription count
        bool active;              // Whether round is active
    }

    // Events
    event SubscriptionCreated(uint256 indexed id, address indexed user, uint256 amount, uint256 frequency, bytes metadata);
    event SubscriptionCancelled(uint256 indexed id, address indexed user);
    event SubscriptionUpdated(uint256 indexed id, uint256 amount, uint256 frequency, bytes metadata);
    event PaymentProcessed(uint256 indexed subscriptionId, address indexed user, uint256 amount, uint256 fee);
    event PaymentFailed(uint256 indexed subscriptionId, address indexed user, string reason);
    event SubscriptionRoundOpened(uint256 indexed roundId, string name, uint256 startTime, uint256 endTime, uint256 capacity);
    event SubscriptionRoundClosed(uint256 indexed roundId, uint256 totalSubscriptions);
    event FeesUpdated(address indexed feeRecipient, uint256 subscriptionFee, uint256 withdrawalFee);

    // Errors
    error InvalidAddress();
    error InvalidAmount();
    error InvalidFrequency();
    error InvalidCapacity();
    error InvalidTimeRange();
    error InactiveSubscription();
    error Unauthorized();
    error PaymentNotDue();
    error TransferFailed();
    error RoundAlreadyActive();
    error NoActiveRound();
    error FeeTooHigh();

    // User functions
    function createSubscription(address user, uint256 amount, uint256 frequency, bytes calldata metadata) external returns (uint256);
    function cancelSubscription(uint256 subscriptionId) external;

    // Admin functions
    function openSubscriptionRound(string calldata name, uint256 startTime, uint256 endTime, uint256 capacity) external returns (uint256);
    function closeSubscriptionRound() external;
    function updateSubscription(uint256 subscriptionId, uint256 amount, uint256 frequency, bytes calldata metadata) external;
    function updateFees(address feeRecipient, uint256 subscriptionFee, uint256 withdrawalFee) external;
    function processPayment(uint256 subscriptionId) external returns (bool);
    function batchProcessPayments(uint256[] calldata subscriptionIds) external returns (uint256);

    // View functions
    function getSubscription(uint256 subscriptionId) external view returns (Subscription memory);
    function getCurrentRound() external view returns (SubscriptionRound memory);
    function getUserSubscriptions(address user) external view returns (uint256[] memory);
    function isPaymentDue(uint256 subscriptionId) external view returns (bool isDue, uint256 dueDate);
}