// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


/**
 * @title IRuleEngine
 * @notice Interface for the Rule Engine that manages rules for tRWA tokens
 * @dev The Rule Engine maintains a registry of rules and executes them for various operations
 */
interface IRulesEngine {
    // Events
    event RuleAdded(bytes32 indexed ruleId, address indexed rule);
    event RuleRemoved(bytes32 indexed ruleId);
    event RulePriorityChanged(bytes32 indexed ruleId, uint256 newPriority);
    event RuleEnabled(bytes32 indexed ruleId);
    event RuleDisabled(bytes32 indexed ruleId);
    event RuleEvaluationResult(
        bytes32 indexed ruleId,
        uint256 indexed operationType,
        bool approved,
        string reason
    );

    // Errors
    error RuleNotFound(bytes32 ruleId);
    error RuleAlreadyExists(bytes32 ruleId);
    error InvalidRuleAddress();
    error EmptyRule();
    error InvalidOperation(uint256 operationType);
    error RuleEvaluationFailed(bytes32 ruleId, string reason);
    error OperationNotAllowed(uint256 operationType, string reason);

    /**
     * @notice Add a new rule to the engine
     * @param rule Address of the rule contract implementing IRules
     * @param priority Priority of the rule (lower numbers execute first)
     * @return ruleId Identifier of the added rule
     */
    function addRule(address rule, uint256 priority) external returns (bytes32);

    /**
     * @notice Remove a rule from the engine
     * @param ruleId Identifier of the rule to remove
     */
    function removeRule(bytes32 ruleId) external;

    /**
     * @notice Change the priority of a rule
     * @param ruleId Identifier of the rule
     * @param newPriority New priority for the rule
     */
    function changeRulePriority(bytes32 ruleId, uint256 newPriority) external;

    /**
     * @notice Enable a rule
     * @param ruleId Identifier of the rule to enable
     */
    function enableRule(bytes32 ruleId) external;

    /**
     * @notice Disable a rule
     * @param ruleId Identifier of the rule to disable
     */
    function disableRule(bytes32 ruleId) external;

    /**
     * @notice Check if a rule is active
     * @param ruleId Identifier of the rule
     * @return Whether the rule is active
     */
    function isRuleActive(bytes32 ruleId) external view returns (bool);

    /**
     * @notice Get all registered rule identifiers
     * @return Array of rule identifiers
     */
    function getAllRules() external view returns (bytes32[] memory);

    /**
     * @notice Get rule address by ID
     * @param ruleId Identifier of the rule
     * @return Rule contract address
     */
    function getRuleAddress(bytes32 ruleId) external view returns (address);

    /**
     * @notice Get rule priority
     * @param ruleId Identifier of the rule
     * @return Priority value
     */
    function getRulePriority(bytes32 ruleId) external view returns (uint256);
}