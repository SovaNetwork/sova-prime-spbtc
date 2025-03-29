// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ItRWAHook} from "../interfaces/ItRWAHook.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ISubscriptionModule} from "../interfaces/ISubscriptionModule.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";

/**
 * @title SubscriptionHook
 * @notice Hook that provides subscription validation for tRWA
 * @dev This hook verifies that a deposit is coming from a valid subscription
 */
contract SubscriptionHook is ItRWAHook, OwnableRoles {
    uint256 public constant SUBSCRIPTION_MANAGER_ROLE = 1 << 0;

    address public immutable tRWA;
    ISubscriptionModule public subscriptionModule;

    // User subscription states
    mapping(address => bool) public allowedSubscribers;

    // Events
    event SubscriberUpdated(address indexed subscriber, bool allowed);
    event SubscriptionModuleUpdated(address indexed oldModule, address indexed newModule);

    // Errors
    error Unauthorized();
    error InvalidSubscriber();

    /**
     * @notice Contract constructor
     * @param _tRWA Address of the tRWA contract
     * @param _subscriptionModule Address of the subscription module
     * @param _admin Admin address
     */
    constructor(address _tRWA, address _subscriptionModule, address _admin) {
        require(_tRWA != address(0), "Invalid tRWA address");
        require(_subscriptionModule != address(0), "Invalid subscription module address");
        require(_admin != address(0), "Invalid admin address");

        tRWA = _tRWA;
        subscriptionModule = ISubscriptionModule(_subscriptionModule);
        _initializeOwner(_admin);
        _grantRoles(_admin, SUBSCRIPTION_MANAGER_ROLE);
    }

    /**
     * @notice Set a new subscription module
     * @param _subscriptionModule Address of the new subscription module
     */
    function setSubscriptionModule(address _subscriptionModule) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        require(_subscriptionModule != address(0), "Invalid subscription module address");

        address oldModule = address(subscriptionModule);
        subscriptionModule = ISubscriptionModule(_subscriptionModule);

        emit SubscriptionModuleUpdated(oldModule, _subscriptionModule);
    }

    /**
     * @notice Add or remove a subscriber
     * @param subscriber Address of the subscriber
     * @param allowed Whether the subscriber is allowed
     */
    function setSubscriber(address subscriber, bool allowed) external onlyOwnerOrRoles(SUBSCRIPTION_MANAGER_ROLE) {
        if (subscriber == address(0)) revert ItRWA.InvalidAddress();

        allowedSubscribers[subscriber] = allowed;

        emit SubscriberUpdated(subscriber, allowed);
    }

    /**
     * @notice Check if a deposit is allowed
     * @param user Address depositing assets
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return Whether the deposit is allowed
     */
    function beforeDeposit(address user, uint256 assets, address receiver) external override returns (bool) {
        // Only allow calls from tRWA contract
        if (msg.sender != tRWA) revert Unauthorized();

        // Check if the user is an allowed subscriber
        return allowedSubscribers[user];
    }

    /**
     * @notice Record successful deposit
     * @param user Address that deposited
     * @param assets Amount of assets deposited
     * @param receiver Address receiving the shares
     * @param shares Amount of shares minted
     */
    function afterDeposit(address user, uint256 assets, address receiver, uint256 shares) external override {
        // Only allow calls from tRWA contract
        if (msg.sender != tRWA) revert Unauthorized();

        // This could be used to record successful deposits or emit events
        // No additional logic needed for now
    }

    // Required interface functions (not used)
    function beforeMint(address, uint256, address) external pure override returns (bool) { return true; }
    function beforeWithdraw(address, uint256, address, address) external pure override returns (bool) { return true; }
    function beforeRedeem(address, uint256, address, address) external pure override returns (bool) { return true; }
    function beforeTransfer(address, address, uint256) external pure override returns (bool) { return true; }
    function afterMint(address, uint256, address, uint256) external pure override {}
    function afterWithdraw(address, uint256, address, address, uint256) external pure override {}
    function afterRedeem(address, uint256, address, address, uint256) external pure override {}
    function afterTransfer(address, address, uint256) external pure override {}
}