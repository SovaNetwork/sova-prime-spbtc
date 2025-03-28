// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title ApprovalSubscriptionModule
 * @notice Subscription module that requires admin approval before issuing tokens
 * @dev Extends BaseSubscriptionModule with approval workflow and transfer approval checks
 */
contract ApprovalSubscriptionModule is BaseSubscriptionModule {
    // Pending deposit tracking
    struct PendingDeposit {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => PendingDeposit[]) public pendingDeposits;

    // Events
    event SubscriptionApproved(address indexed subscriber, uint256 amount, uint256 tokensMinted);
    event DepositReceived(address indexed subscriber, uint256 amount, uint256 index);
    event SubscriptionRejected(address indexed subscriber, uint256 amount, uint256 index);

    // Errors
    error NoTransferApproval();
    error InvalidDepositIndex();
    error NoPendingDeposits();

    /**
     * @notice Constructor for ApprovalSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     */
    constructor(
        address _token
    ) BaseSubscriptionModule(_token) {}

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     */
    function deposit(address _subscriber, uint256 _amount) external payable override {
        // Check if the subscriber has transfer approval for the token
        if (ERC20(token).allowance(_subscriber, address(this)) < _amount) {
            revert NoTransferApproval();
        }

        // Record the pending deposit
        pendingDeposits[_subscriber].push(PendingDeposit({
            amount: _amount,
            timestamp: block.timestamp
        }));

        emit DepositReceived(_subscriber, _amount, pendingDeposits[_subscriber].length - 1);
    }

    /**
     * @notice Approve a specific pending deposit for a subscriber
     * @param _subscriber Address of the subscriber to approve
     * @param _index Index of the pending deposit to approve
     */
    function approveSubscription(address _subscriber, uint256 _index) external onlyOwner {
        PendingDeposit[] storage deposits = pendingDeposits[_subscriber];
        if (_index >= deposits.length) revert InvalidDepositIndex();

        // Get the deposit amount and remove it from the array
        uint256 amount = deposits[_index].amount;
        deposits[_index] = deposits[deposits.length - 1];
        deposits.pop();

        // Call base implementation to handle token minting
        super.deposit(_subscriber, amount);

        emit SubscriptionApproved(_subscriber, amount, amount);
    }

    /**
     * @notice Approve all pending deposits for a subscriber
     * @param _subscriber Address of the subscriber to approve
     */
    function approveAllSubscriptions(address _subscriber) external onlyOwner {
        PendingDeposit[] storage deposits = pendingDeposits[_subscriber];
        if (deposits.length == 0) revert NoPendingDeposits();

        uint256 totalAmount;
        uint256 length = deposits.length;

        // Calculate total amount
        for (uint256 i = 0; i < length; i++) {
            totalAmount += deposits[i].amount;
        }

        // Clear all deposits
        delete pendingDeposits[_subscriber];

        // Process the total amount in a single deposit
        super.deposit(_subscriber, totalAmount);
        emit SubscriptionApproved(_subscriber, totalAmount, totalAmount);
    }

    /**
     * @notice Reject a specific pending deposit for a subscriber
     * @param _subscriber Address of the subscriber to reject
     * @param _index Index of the pending deposit to reject
     */
    function rejectSubscription(address _subscriber, uint256 _index) external onlyOwner {
        PendingDeposit[] storage deposits = pendingDeposits[_subscriber];
        if (_index >= deposits.length) revert InvalidDepositIndex();

        // Get the deposit amount and remove it from the array
        uint256 amount = deposits[_index].amount;
        deposits[_index] = deposits[deposits.length - 1];
        deposits.pop();

        emit SubscriptionRejected(_subscriber, amount, _index);
    }

    /**
     * @notice Reject all pending deposits for a subscriber
     * @param _subscriber Address of the subscriber to reject
     */
    function rejectAllSubscriptions(address _subscriber) external onlyOwner {
        PendingDeposit[] storage deposits = pendingDeposits[_subscriber];
        if (deposits.length == 0) revert NoPendingDeposits();

        uint256 length = deposits.length;
        uint256 totalAmount;

        // Calculate total amount and emit rejection events
        for (uint256 i = 0; i < length; i++) {
            totalAmount += deposits[i].amount;
            emit SubscriptionRejected(_subscriber, deposits[i].amount, i);
        }

        // Clear all deposits
        delete pendingDeposits[_subscriber];
    }

    /**
     * @notice Get all pending deposits for a subscriber
     * @param _subscriber Address of the subscriber
     * @return amounts Array of pending deposit amounts
     * @return timestamps Array of deposit timestamps
     */
    function getPendingDeposits(address _subscriber) external view returns (uint256[] memory amounts, uint256[] memory timestamps) {
        PendingDeposit[] storage deposits = pendingDeposits[_subscriber];
        uint256 length = deposits.length;

        amounts = new uint256[](length);
        timestamps = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            amounts[i] = deposits[i].amount;
            timestamps[i] = deposits[i].timestamp;
        }
    }

    /**
     * @notice Get the number of pending deposits for a subscriber
     * @param _subscriber Address of the subscriber
     * @return count Number of pending deposits
     */
    function getPendingDepositCount(address _subscriber) external view returns (uint256) {
        return pendingDeposits[_subscriber].length;
    }
}