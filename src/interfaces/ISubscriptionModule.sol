// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title ISubscriptionModule
 * @notice Interface for subscription modules that handle deposits and token issuance
 * @dev All subscription modules must implement these functions
 */
interface ISubscriptionModule {
    /// @notice Status of a subscription request
    enum SubscriptionStatus {
        NONE,
        PENDING,
        APPROVED,
        REJECTED,
        PROCESSED
    }

    /// @notice Represents a subscription request
    struct SubscriptionRequest {
        address subscriber;
        uint256 amount;
        uint256 timestamp;
        SubscriptionStatus status;
        string rejectionReason;
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     * @return requestId Unique identifier for the subscription request
     */
    function deposit(address _subscriber, uint256 _amount) external payable returns (uint256 requestId);

    /**
     * @notice Get details of a subscription request
     * @param _requestId The ID of the subscription request
     * @return The subscription request details
     */
    function getSubscriptionRequest(uint256 _requestId) external view returns (SubscriptionRequest memory);

    /**
     * @notice Get the total number of subscription requests
     * @return count The total number of subscription requests
     */
    function getRequestCount() external view returns (uint256);

    /**
     * @notice Get all subscription requests for a subscriber
     * @param _subscriber The address of the subscriber
     * @return requestIds Array of request IDs for the subscriber
     */
    function getSubscriberRequests(address _subscriber) external view returns (uint256[] memory requestIds);

    /**
     * @notice Check if the module is accepting new subscriptions
     * @return isOpen Whether the module is accepting new subscriptions
     */
    function isSubscriptionOpen() external view returns (bool);
}