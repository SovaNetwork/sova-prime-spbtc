// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title ApprovalSubscriptionModule
 * @notice Subscription module that requires admin approval before issuing tokens
 * @dev Extends BaseSubscriptionModule with approval workflow
 */
contract ApprovalSubscriptionModule is BaseSubscriptionModule {
    // Token issuance parameters
    uint256 public tokenPriceInUSD; // Price per token in USD with 18 decimals precision

    // Approval tracking
    mapping(address => bool) public whitelistedInvestors;

    // Events
    event TokenPriceUpdated(uint256 newPrice);
    event SubscriptionApproved(uint256 indexed requestId, address indexed approver, uint256 tokensMinted);
    event InvestorWhitelisted(address indexed investor, bool status);

    // Errors
    error ZeroTokenPrice();
    error AlreadyProcessed();
    error NotPending();

    /**
     * @notice Constructor for ApprovalSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     */
    constructor(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        bool _isOpen
    ) BaseSubscriptionModule(_token, _treasury, _minSubscriptionAmount, _isOpen) {
        if (_tokenPriceInUSD == 0) revert ZeroTokenPrice();
        tokenPriceInUSD = _tokenPriceInUSD;
    }

    /**
     * @notice Update the token price
     * @param _newPrice New token price in USD (18 decimals)
     */
    function updateTokenPrice(uint256 _newPrice) external onlyAdmin {
        if (_newPrice == 0) revert ZeroTokenPrice();
        tokenPriceInUSD = _newPrice;
        emit TokenPriceUpdated(_newPrice);
    }

    /**
     * @notice Toggle whether an investor is whitelisted
     * @param _investor Investor address
     * @param _status New whitelist status
     */
    function setInvestorWhitelist(address _investor, bool _status) external onlyAdmin {
        if (_investor == address(0)) revert InvalidAddress();
        whitelistedInvestors[_investor] = _status;
        emit InvestorWhitelisted(_investor, _status);
    }

    /**
     * @notice Batch whitelist multiple investors
     * @param _investors Array of investor addresses
     * @param _status Whitelist status to set for all investors
     */
    function batchSetInvestorWhitelist(address[] calldata _investors, bool _status) external onlyAdmin {
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_investors[i] == address(0)) revert InvalidAddress();
            whitelistedInvestors[_investors[i]] = _status;
            emit InvestorWhitelisted(_investors[i], _status);
        }
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited in USD (18 decimals)
     * @return requestId Unique identifier for the subscription request (requires approval)
     */
    function deposit(address _subscriber, uint256 _amount) external payable override returns (uint256) {
        _validateSubscription(_subscriber, _amount);

        // Only whitelisted investors can subscribe
        if (!whitelistedInvestors[_subscriber]) revert Unauthorized();

        // Create a subscription request (pending approval)
        uint256 requestId = _createSubscriptionRequest(_subscriber, _amount);

        // Transfer funds to treasury would happen here
        // In this simplified example, we're just tracking the deposit amount

        return requestId;
    }

    /**
     * @notice Approve a subscription request
     * @param _requestId ID of the subscription request to approve
     */
    function approveSubscription(uint256 _requestId) external onlyAdmin {
        if (_requestId >= requestIdCounter) revert RequestNotFound();

        SubscriptionRequest storage request = requests[_requestId];

        if (request.status != SubscriptionStatus.PENDING) revert NotPending();

        // Calculate tokens to mint based on current token price
        uint256 tokensToMint = (request.amount * 1e18) / tokenPriceInUSD;

        // Update request status
        request.status = SubscriptionStatus.APPROVED;

        // Mint tokens to subscriber
        token.deposit(tokensToMint, request.subscriber);

        emit SubscriptionApproved(_requestId, msg.sender, tokensToMint);
    }

    /**
     * @notice Reject a subscription request
     * @param _requestId ID of the subscription request to reject
     * @param _reason Reason for rejection
     */
    function rejectSubscription(uint256 _requestId, string calldata _reason) external onlyAdmin {
        if (_requestId >= requestIdCounter) revert RequestNotFound();

        SubscriptionRequest storage request = requests[_requestId];

        if (request.status != SubscriptionStatus.PENDING) revert NotPending();

        // Update request status
        request.status = SubscriptionStatus.REJECTED;
        request.rejectionReason = _reason;

        // Refund would happen here in a real implementation

        emit SubscriptionRejected(_requestId, msg.sender, _reason);
    }

    /**
     * @notice Calculate number of tokens for a given USD amount
     * @param _usdAmount Amount in USD (18 decimals)
     * @return tokenAmount Number of tokens to be minted
     */
    function calculateTokenAmount(uint256 _usdAmount) external view returns (uint256) {
        return (_usdAmount * 1e18) / tokenPriceInUSD;
    }

    /**
     * @notice Get all pending subscription requests
     * @return requestIds Array of pending request IDs
     */
    function getPendingRequests() external view returns (uint256[] memory) {
        // First, count the number of pending requests
        uint256 pendingCount = 0;
        for (uint256 i = 1; i < requestIdCounter; i++) {
            if (requests[i].status == SubscriptionStatus.PENDING) {
                pendingCount++;
            }
        }

        // Then allocate and fill the array
        uint256[] memory pendingRequests = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 1; i < requestIdCounter; i++) {
            if (requests[i].status == SubscriptionStatus.PENDING) {
                pendingRequests[index] = i;
                index++;
            }
        }

        return pendingRequests;
    }
}