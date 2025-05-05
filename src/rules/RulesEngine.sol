// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {RoleManaged} from "../auth/RoleManaged.sol";
import {IRulesEngine} from "./IRulesEngine.sol";
import {IRules} from "./IRules.sol";
import {BaseRules} from "./BaseRules.sol";
/**
 * @title RulesEngine
 * @notice Implementation of IRuleEngine for managing and evaluating rules
 * @dev Manages a collection of rules that determine if operations are allowed
 */
contract RulesEngine is IRulesEngine, BaseRules, RoleManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Role for managing rules
    uint256 public constant RULE_ADMIN_ROLE = 1 << 0;

    // Operation type constants
    uint256 constant OPERATION_TRANSFER = 1 << 0;
    uint256 constant OPERATION_DEPOSIT = 1 << 1;
    uint256 constant OPERATION_WITHDRAW = 1 << 2;
    uint256 constant OPERATION_ALL = type(uint256).max;

    struct RuleInfo {
        address rule;
        uint256 priority;
        bool active;
    }

    // All rules by ID
    mapping(bytes32 => RuleInfo) private _rules;

    // All rule IDs
    bytes32[] private _ruleIds;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param _roleManager Address of the role manager
     */
    constructor(address _roleManager) BaseRules("RulesEngine") RoleManaged(_roleManager) {}

    /*//////////////////////////////////////////////////////////////
                            ENGINE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new rule to the engine
     * @param rule Address of the rule contract implementing IRule
     * @param priority Priority of the rule (lower numbers execute first)
     * @return ruleId Identifier of the added rule
     */
    function addRule(address rule, uint256 priority) external onlyRole(roleManager.RULES_ADMIN()) returns (bytes32) {
        if (rule == address(0)) revert InvalidRuleAddress();

        // Get rule ID from the rule contract
        bytes32 id = IRules(rule).ruleId();

        // Make sure rule doesn't already exist
        if (_rules[id].rule != address(0)) revert RuleAlreadyExists(id);
        if (IRules(rule).appliesTo() == 0) revert EmptyRule();

        // Store rule information
        _rules[id] = RuleInfo({
            rule: rule,
            priority: priority,
            active: true
        });

        // Add to the list of all rules
        _ruleIds.push(id);

        emit RuleAdded(id, rule);

        return id;
    }

    /**
     * @notice Remove a rule from the engine
     * @param ruleId Identifier of the rule to remove
     */
    function removeRule(bytes32 ruleId) external onlyRole(roleManager.RULES_ADMIN()) {
        if (_rules[ruleId].rule == address(0)) revert RuleNotFound(ruleId);

        // Remove from the rules mapping
        delete _rules[ruleId];

        // Remove from the array of rule IDs
        for (uint256 i = 0; i < _ruleIds.length; i++) {
            if (_ruleIds[i] == ruleId) {
                // Replace with the last element and pop
                _ruleIds[i] = _ruleIds[_ruleIds.length - 1];
                _ruleIds.pop();
                break;
            }
        }

        emit RuleRemoved(ruleId);
    }

    /**
     * @notice Change the priority of a rule
     * @param ruleId Identifier of the rule
     * @param newPriority New priority for the rule
     */
    function changeRulePriority(bytes32 ruleId, uint256 newPriority) external onlyRole(roleManager.RULES_ADMIN()) {
        if (_rules[ruleId].rule == address(0)) revert RuleNotFound(ruleId);

        _rules[ruleId].priority = newPriority;

        emit RulePriorityChanged(ruleId, newPriority);
    }

    /**
     * @notice Enable a rule
     * @param ruleId Identifier of the rule to enable
     */
    function enableRule(bytes32 ruleId) external onlyRole(roleManager.RULES_ADMIN()) {
        if (_rules[ruleId].rule == address(0)) revert RuleNotFound(ruleId);

        _rules[ruleId].active = true;

        emit RuleEnabled(ruleId);
    }

    /**
     * @notice Disable a rule
     * @param ruleId Identifier of the rule to disable
     */
    function disableRule(bytes32 ruleId) external onlyRole(roleManager.RULES_ADMIN()) {
        if (_rules[ruleId].rule == address(0)) revert RuleNotFound(ruleId);

        _rules[ruleId].active = false;

        emit RuleDisabled(ruleId);
    }

    /**
     * @notice Check if a rule is active
     * @param ruleId Identifier of the rule
     * @return Whether the rule is active
     */
    function isRuleActive(bytes32 ruleId) external view returns (bool) {
        return _rules[ruleId].active;
    }

    /**
     * @notice Get all registered rule identifiers
     * @return Array of rule identifiers
     */
    function getAllRules() external view returns (bytes32[] memory) {
        return _ruleIds;
    }

    /**
     * @notice Get rule address by ID
     * @param ruleId Identifier of the rule
     * @return Rule contract address
     */
    function getRuleAddress(bytes32 ruleId) external view returns (address) {
        return _rules[ruleId].rule;
    }

    /**
     * @notice Get rule priority
     * @param ruleId Identifier of the rule
     * @return Priority value
     */
    function getRulePriority(bytes32 ruleId) external view returns (uint256) {
        return _rules[ruleId].priority;
    }

    /*//////////////////////////////////////////////////////////////
                            RULE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Evaluate transfer operation against rules
     * @param token Address of the tRWA token
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param amount Amount of tokens being transferred
     * @return result Rule evaluation result
     */
    function evaluateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) public view override returns (RuleResult memory) {
        try this._evaluateOperation(
            OPERATION_TRANSFER,
            abi.encodeCall(IRules.evaluateTransfer, (token, from, to, amount))
        ) returns (RuleResult memory result) {
            return result;
        } catch {
            revert OperationNotAllowed(OPERATION_TRANSFER, "Rule evaluation failed");
        }
    }

    /**
     * @notice Evaluate deposit operation against rules
     * @param token Address of the tRWA token
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address token,
        address user,
        uint256 assets,
        address receiver
    ) public view override returns (RuleResult memory) {
        try this._evaluateOperation(
            OPERATION_DEPOSIT,
            abi.encodeCall(IRules.evaluateDeposit, (token, user, assets, receiver))
        ) returns (RuleResult memory result) {
            return result;
        } catch {
            revert OperationNotAllowed(OPERATION_DEPOSIT, "Rule evaluation failed");
        }
    }

    /**
     * @notice Evaluate withdraw operation against rules
     * @param user Address initiating the withdrawal
     * @param assets Amount of assets being withdrawn
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address token,
        address user,
        uint256 assets,
        address receiver,
        address owner
    ) public view override returns (RuleResult memory) {
        try this._evaluateOperation(
            OPERATION_WITHDRAW,
            abi.encodeCall(IRules.evaluateWithdraw, (token, user, assets, receiver, owner))
        ) returns (RuleResult memory result) {
            return result;
        } catch {
            revert OperationNotAllowed(OPERATION_WITHDRAW, "Rule evaluation failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal method to evaluate an operation against all applicable rules
     * @param operationType Type of operation being performed
     * @param callData Encoded call data for the rule evaluation function
     * @return result Rule evaluation result
     */
    function _evaluateOperation(uint256 operationType, bytes memory callData) external view returns (RuleResult memory) {
        // Get all rule IDs ordered by priority
        bytes32[] memory sortedRuleIds = _getSortedRuleIds();

        // Iterate through all rules in priority order
        for (uint256 i = 0; i < sortedRuleIds.length; i++) {
            bytes32 ruleId = sortedRuleIds[i];
            RuleInfo memory rule = _rules[ruleId];

            // Skip inactive rules
            if (!rule.active) continue;

            // Skip rules that don't apply to this operation
            if ((IRules(rule.rule).appliesTo() & operationType) == 0) continue;

            // Call the rule with the appropriate evaluation function
            (bool success, bytes memory returnData) = rule.rule.staticcall(callData);

            if (!success) {
                // Rule execution failed
                revert RuleEvaluationFailed(ruleId, abi.decode(returnData, (string)));
            }

            // Decode the result
            RuleResult memory result = abi.decode(returnData, (RuleResult));

            // If rule rejects, operation is not allowed
            if (!result.approved) {
                return RuleResult({approved: false, reason: result.reason});
            }
        }

        // If we made it through all rules, operation is allowed
        return RuleResult({approved: true, reason: ""});
    }

    /**
     * @notice Get rule IDs sorted by priority (lower goes first)
     * @return Sorted array of rule IDs
     */
    function _getSortedRuleIds() private view returns (bytes32[] memory) {
        uint256 count = _ruleIds.length;
        bytes32[] memory sortedIds = new bytes32[](count);

        // First, copy all IDs to the new array
        for (uint256 i = 0; i < count; i++) {
            sortedIds[i] = _ruleIds[i];
        }

        // Simple insertion sort by priority
        for (uint256 i = 1; i < count; i++) {
            bytes32 key = sortedIds[i];
            uint256 keyPriority = _rules[key].priority;
            uint256 j = i;

            while (j > 0 && _rules[sortedIds[j-1]].priority > keyPriority) {
                sortedIds[j] = sortedIds[j-1];
                j--;
            }

            sortedIds[j] = key;
        }

        return sortedIds;
    }
}