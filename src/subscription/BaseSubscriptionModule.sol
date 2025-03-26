// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {tRWA} from "../token/tRWA.sol";
import {ISubscriptionModule} from "../interfaces/ISubscriptionModule.sol";

/**
 * @title BaseSubscriptionModule
 * @notice Base implementation for subscription modules
 * @dev Handles deposit tracking and subscription request management
 */
abstract contract BaseSubscriptionModule is ISubscriptionModule {
    // Core properties
    address public admin;
    address public treasury;
    tRWA public token;

    // Subscription tracking
    bool public override isSubscriptionOpen;
    uint256 public minSubscriptionAmount;
    uint256 public requestIdCounter;
    mapping(uint256 => SubscriptionRequest) public requests;
    mapping(address => uint256[]) public subscriberRequests;

    // Events
    event SubscriptionRequested(uint256 indexed requestId, address indexed subscriber, uint256 amount);
    event SubscriptionProcessed(uint256 indexed requestId, address indexed subscriber, uint256 amount, uint256 tokensMinted);
    event SubscriptionRejected(uint256 indexed requestId, address indexed subscriber, string reason);
    event SubscriptionStatusChanged(bool isOpen);
    event MinSubscriptionAmountChanged(uint256 newAmount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error SubscriptionClosed();
    error InsufficientAmount();
    error RequestNotFound();
    error InvalidRequestStatus();

    /**
     * @notice Constructor for BaseSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        bool _isOpen
    ) {
        if (_token == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_minSubscriptionAmount == 0) revert InvalidAmount();

        admin = msg.sender;
        token = tRWA(_token);
        treasury = _treasury;
        minSubscriptionAmount = _minSubscriptionAmount;
        isSubscriptionOpen = _isOpen;
        requestIdCounter = 1; // Start with 1 for easier existence checks
    }

    /**
     * @notice Modifier to restrict function calls to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Toggle whether subscriptions are open
     * @param _isOpen Whether subscriptions should be open
     */
    function setSubscriptionStatus(bool _isOpen) external onlyAdmin {
        isSubscriptionOpen = _isOpen;
        emit SubscriptionStatusChanged(_isOpen);
    }

    /**
     * @notice Update the minimum subscription amount
     * @param _minAmount New minimum subscription amount
     */
    function setMinSubscriptionAmount(uint256 _minAmount) external onlyAdmin {
        if (_minAmount == 0) revert InvalidAmount();
        minSubscriptionAmount = _minAmount;
        emit MinSubscriptionAmountChanged(_minAmount);
    }

    /**
     * @notice Update the admin address
     * @param _newAdmin Address of the new admin
     */
    function updateAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAddress();
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminChanged(oldAdmin, _newAdmin);
    }

    /**
     * @notice Update the treasury address
     * @param _newTreasury Address of the new treasury
     */
    function updateTreasury(address _newTreasury) external onlyAdmin {
        if (_newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryChanged(oldTreasury, _newTreasury);
    }

    /**
     * @notice Get details of a subscription request
     * @param _requestId The ID of the subscription request
     * @return The subscription request details
     */
    function getSubscriptionRequest(uint256 _requestId) external view override returns (SubscriptionRequest memory) {
        if (_requestId == 0 || _requestId >= requestIdCounter) revert RequestNotFound();
        return requests[_requestId];
    }

    /**
     * @notice Get the total number of subscription requests
     * @return count The total number of subscription requests
     */
    function getRequestCount() external view override returns (uint256) {
        return requestIdCounter - 1;
    }

    /**
     * @notice Get all subscription requests for a subscriber
     * @param _subscriber The address of the subscriber
     * @return requestIds Array of request IDs for the subscriber
     */
    function getSubscriberRequests(address _subscriber) external view override returns (uint256[] memory) {
        return subscriberRequests[_subscriber];
    }

    /**
     * @notice Internal function to create a new subscription request
     * @param _subscriber The address of the subscriber
     * @param _amount The amount being deposited
     * @return requestId The ID of the created request
     */
    function _createSubscriptionRequest(address _subscriber, uint256 _amount) internal returns (uint256) {
        uint256 requestId = requestIdCounter++;

        requests[requestId] = SubscriptionRequest({
            subscriber: _subscriber,
            amount: _amount,
            timestamp: block.timestamp,
            status: SubscriptionStatus.PENDING,
            rejectionReason: ""
        });

        subscriberRequests[_subscriber].push(requestId);

        emit SubscriptionRequested(requestId, _subscriber, _amount);

        return requestId;
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @dev Must be implemented by derived contracts
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     * @return requestId Unique identifier for the subscription request
     */
    function deposit(address _subscriber, uint256 _amount) external payable virtual override returns (uint256);

    /**
     * @notice Internal function to validate a subscription request
     * @param _subscriber The subscriber address
     * @param _amount The subscription amount
     */
    function _validateSubscription(address _subscriber, uint256 _amount) internal view {
        if (!isSubscriptionOpen) revert SubscriptionClosed();
        if (_subscriber == address(0)) revert InvalidAddress();
        if (_amount < minSubscriptionAmount) revert InsufficientAmount();
    }
}