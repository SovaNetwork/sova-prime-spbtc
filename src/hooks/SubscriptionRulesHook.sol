// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseHook} from "./BaseHook.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IHook} from "./IHook.sol";

/**
 * @title SubscriptionRulesHook
 * @notice Hook that restricts deposits based on subscription status
 * @dev Implements subscription validation logic
 */
contract SubscriptionRulesHook is BaseHook, OwnableRoles {
    // Constants
    uint256 public constant SUBSCRIPTION_MANAGER_ROLE = 1 << 0;
    // OPERATION_DEPOSIT constant removed as appliesTo is no longer used

    // Subscription states
    mapping(address => bool) public isSubscriptionApproved;

    // Status flags
    bool public isOpen;
    bool public enforceApproval;

    // Events
    event SetSubscriptionStatus(bool isOpen);
    event SubscriberUpdated(address indexed subscriber, bool approved);
    event SetEnforceApproval(bool enforceApproval);

    // Errors (retained for internal logic, not directly returned by hooks)
    error SubscriptionClosed(); // Custom error for internal check
    error NotSubscribed(address user); // Custom error for internal check
    error InvalidAddress();

    /**
     * @notice Constructor for SubscriptionRulesHook
     * @param _admin Address that will have admin rights
     * @param _enforceApproval Initial state for enforcing subscription approval
     * @param _isOpen Initial state for whether subscriptions are open
     */
    constructor(address _admin, bool _enforceApproval, bool _isOpen)
        BaseHook("SubscriptionRulesHook-1.0")
    {
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
     * @notice Hook that evaluates a deposit according to subscription rules
     * @param user Address initiating the deposit (or msg.sender if not specified by a meta-tx)
     * @param receiver Address receiving the shares (often the same as user for deposits)
     * @return bytes4 Selector indicating success or specific failure reason
     */
    function onBeforeDeposit(
        address, // token (unused in this specific hook logic)
        address user, // user performing the action, could be different from receiver
        uint256, // assets (unused in this specific hook logic)
        address receiver // entity receiving the results of the deposit (e.g. shares)
    ) public view virtual override returns (IHook.HookOutput memory) {
        // Check if subscriptions are open
        if (!isOpen) {
            return IHook.HookOutput({
                approved: false,
                reason: "SubscriptionRulesHook: Subscription closed"
            });
        }

        // Check if the user (or receiver, depending on policy) is an approved subscriber
        // Assuming the check should be on the 'receiver' of the shares/subscription benefits.
        if (enforceApproval && !isSubscriptionApproved[receiver]) {
            return IHook.HookOutput({
                approved: false,
                reason: "SubscriptionRulesHook: Not subscribed"
            });
        }

        // All checks passed, deposit is allowed
        return IHook.HookOutput({
            approved: true,
            reason: ""
        });
    }

    // appliesTo() function removed as it's not part of IHook
}