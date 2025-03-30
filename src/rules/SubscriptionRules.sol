// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "./BaseRules.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/**
 * @title SubscriptionRules
 * @notice Rule implementation that restricts deposits based on subscription status
 * @dev Implements subscription validation logic through the rules interface
 */
contract SubscriptionRules is BaseRules, OwnableRoles {
    // Constants
    uint256 public constant SUBSCRIPTION_MANAGER_ROLE = 1 << 0;
    uint256 public constant OPERATION_DEPOSIT = 1 << 1;  // Matches RulesEngine.OPERATION_DEPOSIT

    // Subscription states
    mapping(address => bool) public isSubscriptionApproved;

    // Status flags
    bool public isOpen;
    bool public enforceApproval;

    // Events
    event SetSubscriptionStatus(bool isOpen);
    event SubscriberUpdated(address indexed subscriber, bool approved);
    event SetEnforceApproval(bool enforceApproval);

    // Errors
    error SubscriptionClosed();
    error NotSubscribed(address user);
    error InvalidAddress();

    /**
     * @notice Constructor for SubscriptionRules
     * @param _admin Address that will have admin rights
     */
    constructor(address _admin, bool _enforceApproval, bool _isOpen) BaseRules("SubscriptionRule") {
        if (_admin == address(0)) revert InvalidAddress();

        _initializeOwner(_admin);
        _grantRoles(_admin, SUBSCRIPTION_MANAGER_ROLE);

        enforceApproval = _enforceApproval;
        isOpen = _isOpen;
    }

    /**
     * @notice Add or remove a subscriber's ability to deposit
     * @param subscriber Address of the subscriber
     * @param approved Whether the subscriber is approved
     */
    function setSubscriber(address subscriber, bool approved) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        if (subscriber == address(0)) revert InvalidAddress();

        isSubscriptionApproved[subscriber] = approved;

        emit SubscriberUpdated(subscriber, approved);
    }

    /**
     * @notice Set whether new subscriptions are being accepted
     * @param _isOpen Whether subscriptions are open
     */
    function setSubscriptionStatus(bool _isOpen) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        isOpen = _isOpen;

        emit SetSubscriptionStatus(_isOpen);
    }

    /**
     * @notice Set whether the subscriber whitelist must be enforced
     * @param _enforce Whether the subscriber whitelist must be enforced
     */
    function setEnforceApproval(bool _enforce) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        enforceApproval = _enforce;

        emit SetEnforceApproval(_enforce);
    }

    /**
     * @notice Batch approve multiple subscribers
     * @param subscribers Array of subscriber addresses
     * @param approved Whether the subscribers are approved
     */
    function batchSetSubscribers(address[] calldata subscribers, bool approved) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        for (uint256 i = 0; i < subscribers.length; i++) {
            if (subscribers[i] != address(0)) {
                isSubscriptionApproved[subscribers[i]] = approved;
                emit SubscriberUpdated(subscribers[i], approved);
            }
        }
    }

    /**
     * @notice Evaluates a deposit according to subscription rules
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address,
        address,
        uint256,
        address receiver
    ) public virtual override returns (RuleResult memory result) {
        // Check if subscriptions are open
        if (!isOpen) {
            return RuleResult({
                approved: false,
                reason: "Subscriptions are closed"
            });
        }

        // Check if the user is an approved subscriber
        if (enforceApproval && !isSubscriptionApproved[receiver]) {
            return RuleResult({
                approved: false,
                reason: "Address is not approved for subscription"
            });
        }

        // All checks passed, deposit is allowed
        return RuleResult({
            approved: true,
            reason: ""
        });
    }

    /**
     * @notice Returns which operations this rule applies to
     * @return Bitmap of operations this rule applies to
     */
    function appliesTo() external pure override returns (uint256) {
        return OPERATION_DEPOSIT;
    }
}