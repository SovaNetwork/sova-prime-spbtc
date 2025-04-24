// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ISubscriptionController
 * @notice Interface for subscription controller
 * @dev Defines subscription management functionality and data structures
 */
interface ISubscriptionController {
    // Structs
    struct Subscription {
        uint256 id;               // Unique identifier
        address user;             // Subscriber address
        uint256 amount;           // Payment amount
        uint256 amountWithdrawn;  // Amount withdrawn
    }

    struct SubscriptionRound {
        uint256 id;                // Unique identifier
        string name;               // Round name
        uint256 start;             // Start timestamp
        uint256 end;               // End timestamp
        uint256 capacity;          // Maximum subscription count
        uint256 deposits;          // Current subscription count
        bool active;               // Whether round is active
    }

    // Events
    event SubscriptionCreated(uint256 indexed id, address indexed user, uint256 amount, uint256 frequency, bytes metadata);
    event SubscriptionCancelled(uint256 indexed id, address indexed user);
    event SubscriptionRoundOpened(uint256 indexed roundId, string name, uint256 startTime, uint256 endTime, uint256 capacity);
    event SubscriptionRoundClosed(uint256 indexed roundId, uint256 totalSubscriptions);

    // Errors
    error InvalidAddress();
    error InvalidAmount();
    error InvalidCapacity();
    error InvalidTimeRange();
    error InactiveSubscription();
    error SubscriptionUnauthorized();
    error NoActiveRound();
    error RoundCapacityReached();
    error RoundAlreadyActive();
    error OnlyTokenAllowed();
    error OnlyStrategyAllowed();
    error ControllerAlreadySet();
    error ControllerAlreadyConfigured();

    // Admin functions
    function openSubscriptionRound(string calldata name, uint256 startTime, uint256 endTime, uint256 capacity) external returns (uint256);
    function closeSubscriptionRound() external;

    // Pre-execution validation function for rules integration
    function validateDeposit(address user, uint256 assets) external view returns (bool valid, string memory reason);

    // View functions
    function getSubscription(uint256 subscriptionId) external view returns (Subscription memory);
    function getCurrentRound() external view returns (SubscriptionRound memory);
    function getUserSubscriptions(address user) external view returns (uint256[] memory);
}