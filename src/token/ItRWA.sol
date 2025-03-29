// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";

/**
 * @title ItRWA
 * @notice Interface for Tokenized Real World Asset (tRWA)
 * @dev Defines the interface with all events and errors for the tRWA contract
 */
interface ItRWA {
    // Configuration struct for deployment
    struct ConfigurationStruct {
        // The strategy contract
        IStrategy strategy;

        // The rules contract
        IRules rules;
    }

    // Roles
    function PRICE_AUTHORITY_ROLE() external view returns (uint256);
    function ADMIN_ROLE() external view returns (uint256);
    function SUBSCRIPTION_ROLE() external view returns (uint256);

    // Events
    event UnderlyingValueUpdated(uint256 newUnderlyingPerToken, uint256 timestamp);
    event TransferApprovalUpdated(address indexed oldModule, address indexed newModule);
    event TransferApprovalToggled(bool enabled);
    event TransferRejected(address indexed from, address indexed to, uint256 value, string reason);
    event HookAdded(uint256 indexed hookId, address indexed hook);
    event HookRemoved(uint256 indexed hookId);
    event HookStatusChanged(uint256 indexed hookId, bool active);
    event RuleEngineUpdated(address indexed oldEngine, address indexed newEngine);
    event RulesToggled(bool enabled);

    // Errors
    error InvalidAddress();
    error AssetMismatch();
    error ZeroAssets();
    error ZeroShares();
    error InvalidTransferApprovalAddress();
    error TransferBlocked(string reason);
    error InvalidUnderlyingValue();
    error HookReverted(uint256 hookId);
    error WithdrawMoreThanMax();
    error RedeemMoreThanMax();
    error InvalidRuleEngine();

    // Main interface functions
    function transferApproval() external view returns (address);
    function underlyingPerToken() external view returns (uint256);
    function lastValueUpdate() external view returns (uint256);
    function transferApprovalEnabled() external view returns (bool);
    function totalUnderlying() external view returns (uint256);

    // Rule Engine functions
    function ruleEngine() external view returns (address);
    function rulesEnabled() external view returns (bool);

    // Configuration functions
    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external;
    function setTransferApproval(address _transferApproval) external;
    function toggleTransferApproval(bool _enabled) external;
    function setRuleEngine(address _ruleEngine) external;
    function toggleRules(bool _enabled) external;

    // Hook management functions
    function addHook(address hook) external returns (uint256);
    function removeHook(uint256 hookId) external;
    function setHookStatus(uint256 hookId, bool active) external;
    function getHook(uint256 hookId) external view returns (address, bool);
}