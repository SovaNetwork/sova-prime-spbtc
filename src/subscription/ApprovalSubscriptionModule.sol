// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseSubscriptionModule} from "./BaseSubscriptionModule.sol";

/**
 * @title ApprovalSubscriptionModule
 * @notice Subscription module that requires admin approval before issuing tokens
 * @dev Extends BaseSubscriptionModule with approval workflow
 */
contract ApprovalSubscriptionModule is BaseSubscriptionModule {
    // Approval tracking
    mapping(address => bool) public whitelistedInvestors;
    mapping(address => uint256) public pendingDeposits;

    // Events
    event SubscriptionApproved(address indexed subscriber, uint256 amount, uint256 tokensMinted);
    event InvestorWhitelisted(address indexed investor, bool status);
    event DepositReceived(address indexed subscriber, uint256 amount);

    // Errors
    error NotWhitelisted();
    error NoPendingDeposit();
    error AlreadyProcessed();

    /**
     * @notice Constructor for ApprovalSubscriptionModule
     * @param _token The tRWA token this subscription module is for
     */
    constructor(
        address _token
    ) BaseSubscriptionModule(_token) {}

    /**
     * @notice Toggle whether an investor is whitelisted
     * @param _investor Investor address
     * @param _status New whitelist status
     */
    function setInvestorWhitelist(address _investor, bool _status) external onlyOwner {
        if (_investor == address(0)) revert InvalidAddress();
        whitelistedInvestors[_investor] = _status;
        emit InvestorWhitelisted(_investor, _status);
    }

    /**
     * @notice Batch whitelist multiple investors
     * @param _investors Array of investor addresses
     * @param _status Whitelist status to set for all investors
     */
    function batchSetInvestorWhitelist(address[] calldata _investors, bool _status) external onlyOwner {
        for (uint256 i = 0; i < _investors.length; i++) {
            if (_investors[i] == address(0)) revert InvalidAddress();
            whitelistedInvestors[_investors[i]] = _status;
            emit InvestorWhitelisted(_investors[i], _status);
        }
    }

    /**
     * @notice Process a deposit to subscribe to the fund
     * @param _subscriber Address subscribing to the fund
     * @param _amount Amount being deposited
     */
    function deposit(address _subscriber, uint256 _amount) external payable override {
        if (!whitelistedInvestors[_subscriber]) revert NotWhitelisted();

        // Record the pending deposit
        pendingDeposits[_subscriber] = _amount;
        emit DepositReceived(_subscriber, _amount);
    }

    /**
     * @notice Approve a subscription for a subscriber
     * @param _subscriber Address of the subscriber to approve
     */
    function approveSubscription(address _subscriber) external onlyOwner {
        uint256 amount = pendingDeposits[_subscriber];
        if (amount == 0) revert NoPendingDeposit();

        // Clear the pending deposit
        pendingDeposits[_subscriber] = 0;

        // Call base implementation to handle token minting
        super.deposit(_subscriber, amount);

        emit SubscriptionApproved(_subscriber, amount, amount);
    }

    /**
     * @notice Get the pending deposit amount for a subscriber
     * @param _subscriber Address of the subscriber
     * @return amount Pending deposit amount
     */
    function getPendingDeposit(address _subscriber) external view returns (uint256) {
        return pendingDeposits[_subscriber];
    }
}