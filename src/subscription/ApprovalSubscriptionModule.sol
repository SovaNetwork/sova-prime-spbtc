// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ISubscriptionModule} from "../interfaces/ISubscriptionModule.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";
import {SubscriptionHook} from "./SubscriptionHook.sol";

/**
 * @title ApprovalSubscriptionModule
 * @notice Subscription module that requires admin approval before issuing tokens
 * @dev Extends BaseSubscriptionModule with approval workflow and transfer approval checks
 */
contract ApprovalSubscriptionModule is BaseSubscriptionModule, ISubscriptionModule {
    // Subscription hook
    SubscriptionHook public subscriptionHook;

    // Subscription request tracking
    uint256 private _requestCounter;
    mapping(uint256 => SubscriptionRequest) private _requests;
    mapping(address => uint256[]) private _subscriberRequests;

    // Status flags
    bool public isOpen = true;

    // Events
    event SubscriptionRequested(address indexed subscriber, uint256 indexed requestId, uint256 amount);
    event SubscriptionApproved(address indexed subscriber, uint256 indexed requestId, uint256 amount);
    event SubscriptionRejected(address indexed subscriber, uint256 indexed requestId, string reason);
    event SubscriptionProcessed(address indexed subscriber, uint256 indexed requestId, uint256 sharesReceived);
    event SubscriptionStatusChanged(bool isOpen);
    event SubscriptionHookUpdated(address indexed oldHook, address indexed newHook);

    // Errors - keep only those that aren't in the interface
    error NoTransferApproval();
    error InvalidRequestId();
    error SubscriptionClosed();
    error InvalidStatus();
    error ZeroAmount();

    /**
     * @notice Constructor for ApprovalSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     */
    constructor(
        address _token
    ) BaseSubscriptionModule(_token) {}

    /**
     * @notice Set the subscription hook
     * @param _hook The subscription hook address
     */
    function setSubscriptionHook(address _hook) external onlyOwner {
        address oldHook = address(subscriptionHook);
        subscriptionHook = SubscriptionHook(_hook);

        emit SubscriptionHookUpdated(oldHook, _hook);
    }

    /**
     * @notice Set whether subscriptions are open
     * @param _isOpen Whether subscriptions are open
     */
    function setSubscriptionStatus(bool _isOpen) external onlyOwner {
        isOpen = _isOpen;

        emit SubscriptionStatusChanged(_isOpen);
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     * @return requestId Unique identifier for the subscription request
     */
    function deposit(address _subscriber, uint256 _amount) external payable override returns (uint256 requestId) {
        if (!isOpen) revert SubscriptionClosed();
        if (_amount == 0) revert ZeroAmount();

        // Create new subscription request
        requestId = ++_requestCounter;

        _requests[requestId] = SubscriptionRequest({
            subscriber: _subscriber,
            amount: _amount,
            timestamp: block.timestamp,
            status: SubscriptionStatus.PENDING,
            rejectionReason: ""
        });

        _subscriberRequests[_subscriber].push(requestId);

        // Transfer tokens from the subscriber to this contract
        ERC20(ItRWA(token).asset()).transferFrom(_subscriber, address(this), _amount);

        emit SubscriptionRequested(_subscriber, requestId, _amount);
    }

    /**
     * @notice Approve a specific subscription request
     * @param _requestId ID of the request to approve
     */
    function approveSubscription(uint256 _requestId) external onlyOwner {
        SubscriptionRequest storage request = _requests[_requestId];
        if (request.status != SubscriptionStatus.PENDING) revert InvalidStatus();

        // Update the request status
        request.status = SubscriptionStatus.APPROVED;

        // Allow the subscriber to deposit directly to tRWA
        if (address(subscriptionHook) != address(0)) {
            subscriptionHook.setSubscriber(request.subscriber, true);
        }

        // Approve the tRWA token to spend the asset
        address asset = ItRWA(token).asset();
        ERC20(asset).approve(token, request.amount);

        emit SubscriptionApproved(request.subscriber, _requestId, request.amount);
    }

    /**
     * @notice Process an approved subscription
     * @param _requestId ID of the approved request to process
     */
    function processSubscription(uint256 _requestId) external {
        SubscriptionRequest storage request = _requests[_requestId];
        if (request.status != SubscriptionStatus.APPROVED) revert InvalidStatus();

        // Update status
        request.status = SubscriptionStatus.PROCESSED;

        // Process the deposit
        address asset = ItRWA(token).asset();

        // Transfer tokens to tRWA and mint shares
        uint256 sharesBefore = ERC20(token).balanceOf(request.subscriber);

        // The deposit will pull tokens from this contract
        ItRWA(token).deposit(request.amount, request.subscriber);

        uint256 sharesAfter = ERC20(token).balanceOf(request.subscriber);
        uint256 sharesReceived = sharesAfter - sharesBefore;

        // Disable subscriber after successful deposit
        if (address(subscriptionHook) != address(0)) {
            subscriptionHook.setSubscriber(request.subscriber, false);
        }

        emit SubscriptionProcessed(request.subscriber, _requestId, sharesReceived);
    }

    /**
     * @notice Reject a specific subscription request
     * @param _requestId ID of the request to reject
     * @param _reason Reason for rejection
     */
    function rejectSubscription(uint256 _requestId, string calldata _reason) external onlyOwner {
        SubscriptionRequest storage request = _requests[_requestId];
        if (request.status != SubscriptionStatus.PENDING) revert InvalidStatus();

        // Update the request status
        request.status = SubscriptionStatus.REJECTED;
        request.rejectionReason = _reason;

        // Return tokens to the subscriber
        address asset = ItRWA(token).asset();
        ERC20(asset).transfer(request.subscriber, request.amount);

        emit SubscriptionRejected(request.subscriber, _requestId, _reason);
    }

    /**
     * @notice Get details of a subscription request
     * @param _requestId The ID of the subscription request
     * @return The subscription request details
     */
    function getSubscriptionRequest(uint256 _requestId) external view override returns (SubscriptionRequest memory) {
        return _requests[_requestId];
    }

    /**
     * @notice Get the total number of subscription requests
     * @return count The total number of subscription requests
     */
    function getRequestCount() external view override returns (uint256) {
        return _requestCounter;
    }

    /**
     * @notice Get all subscription requests for a subscriber
     * @param _subscriber The address of the subscriber
     * @return requestIds Array of request IDs for the subscriber
     */
    function getSubscriberRequests(address _subscriber) external view override returns (uint256[] memory requestIds) {
        return _subscriberRequests[_subscriber];
    }

    /**
     * @notice Check if the module is accepting new subscriptions
     * @return isSubscriptionOpen Whether the module is accepting new subscriptions
     */
    function isSubscriptionOpen() external view override returns (bool) {
        return isOpen;
    }
}