// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {RulesEngine} from "../src/rules/RulesEngine.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";
import {IRules} from "../src/rules/IRules.sol";
import {IRulesEngine} from "../src/rules/IRulesEngine.sol";

/**
 * @notice Custom role manager for testing RulesEngine
 * @dev Extends MockRoleManager with the RULES_ADMIN function needed by RulesEngine
 */
contract MockRoleManagerForRulesEngine is MockRoleManager {
    uint256 public constant RULES_ADMIN = 1 << 10;
    
    constructor(address _owner) MockRoleManager(_owner) {}
}

/**
 * @title RulesEngineTest
 * @notice Test contract for the RulesEngine implementation
 */
contract RulesEngineTests is BaseFountfiTest {
    RulesEngine public rulesEngine;
    MockRoleManagerForRulesEngine public roleManager;
    
    // We'll create multiple rule instances with different configurations
    MockRules public allowRule;
    MockRules public denyRule;
    MockRules public transferRule;
    MockRules public depositRule;
    MockRules public withdrawRule;
    
    // Rule IDs
    bytes32 public allowRuleId;
    bytes32 public denyRuleId;
    bytes32 public transferRuleId;
    bytes32 public depositRuleId;
    bytes32 public withdrawRuleId;
    
    // Constants from RulesEngine for operation types
    uint256 constant OPERATION_TRANSFER = 1 << 0;
    uint256 constant OPERATION_DEPOSIT = 1 << 1;
    uint256 constant OPERATION_WITHDRAW = 1 << 2;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy our custom role manager with RULES_ADMIN
        roleManager = new MockRoleManagerForRulesEngine(owner);
        
        // Add RULES_ADMIN role to the owner
        roleManager.grantRole(owner, roleManager.RULES_ADMIN());
        
        // Deploy rules engine
        rulesEngine = new RulesEngine(address(roleManager));
        
        // Create rules with different configurations
        allowRule = new MockRules(true, "");
        denyRule = new MockRules(false, "Rule denies operation");
        
        // Create rules for specific operations
        transferRule = new MockRulesForOperation(OPERATION_TRANSFER, true, "");
        depositRule = new MockRulesForOperation(OPERATION_DEPOSIT, true, "");
        withdrawRule = new MockRulesForOperation(OPERATION_WITHDRAW, true, "");
        
        vm.stopPrank();
    }
    
    function test_AddRule() public {
        vm.startPrank(owner);
        
        // Add a rule to the engine
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Verify rule was added
        assertEq(rulesEngine.getRuleAddress(allowRuleId), address(allowRule));
        assertEq(rulesEngine.getRulePriority(allowRuleId), 100);
        assertTrue(rulesEngine.isRuleActive(allowRuleId));
        
        // Add another rule with different priority
        denyRuleId = rulesEngine.addRule(address(denyRule), 50);
        
        // Verify both rules are returned in getAllRules
        bytes32[] memory allRules = rulesEngine.getAllRules();
        assertEq(allRules.length, 2);
        
        vm.stopPrank();
    }
    
    function test_AddRuleInvalidAddress() public {
        vm.startPrank(owner);
        
        // Try to add a rule with address zero
        vm.expectRevert(IRulesEngine.InvalidRuleAddress.selector);
        rulesEngine.addRule(address(0), 100);
        
        vm.stopPrank();
    }
    
    function test_AddRuleAlreadyExists() public {
        vm.startPrank(owner);
        
        // Add a rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Try to add same rule again
        vm.expectRevert(abi.encodeWithSelector(IRulesEngine.RuleAlreadyExists.selector, allowRuleId));
        rulesEngine.addRule(address(allowRule), 100);
        
        vm.stopPrank();
    }
    
    function test_RemoveRule() public {
        vm.startPrank(owner);
        
        // Add a rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Verify rule exists
        assertEq(rulesEngine.getRuleAddress(allowRuleId), address(allowRule));
        
        // Remove the rule
        rulesEngine.removeRule(allowRuleId);
        
        // Verify rule is removed (address should be zero)
        assertEq(rulesEngine.getRuleAddress(allowRuleId), address(0));
        
        // Verify rule is no longer in getAllRules
        bytes32[] memory allRules = rulesEngine.getAllRules();
        assertEq(allRules.length, 0);
        
        vm.stopPrank();
    }
    
    function test_RemoveRuleNotFound() public {
        vm.startPrank(owner);
        
        // Try to remove a non-existent rule
        bytes32 invalidRuleId = bytes32(uint256(1));
        vm.expectRevert(abi.encodeWithSelector(IRulesEngine.RuleNotFound.selector, invalidRuleId));
        rulesEngine.removeRule(invalidRuleId);
        
        vm.stopPrank();
    }
    
    function test_ChangeRulePriority() public {
        vm.startPrank(owner);
        
        // Add a rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Verify initial priority
        assertEq(rulesEngine.getRulePriority(allowRuleId), 100);
        
        // Change priority
        rulesEngine.changeRulePriority(allowRuleId, 50);
        
        // Verify new priority
        assertEq(rulesEngine.getRulePriority(allowRuleId), 50);
        
        vm.stopPrank();
    }
    
    function test_EnableDisableRule() public {
        vm.startPrank(owner);
        
        // Add a rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Verify rule is active by default
        assertTrue(rulesEngine.isRuleActive(allowRuleId));
        
        // Disable rule
        rulesEngine.disableRule(allowRuleId);
        
        // Verify rule is inactive
        assertFalse(rulesEngine.isRuleActive(allowRuleId));
        
        // Enable rule
        rulesEngine.enableRule(allowRuleId);
        
        // Verify rule is active again
        assertTrue(rulesEngine.isRuleActive(allowRuleId));
        
        vm.stopPrank();
    }
    
    function test_RuleEvaluationPriority() public {
        vm.startPrank(owner);
        
        // Create allow and deny rules with different priorities
        // Lower priority executes first
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        denyRuleId = rulesEngine.addRule(address(denyRule), 50);
        
        // Since deny rule has lower priority (50), it will execute first
        // and block the operation, so the result should be deny
        IRules.RuleResult memory result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Check the result - operation should be denied
        assertFalse(result.approved);
        assertEq(result.reason, "Rule denies operation");
        
        // Change priorities so allow rule runs first
        rulesEngine.changeRulePriority(allowRuleId, 25);
        
        // Now the allow rule has priority 25 (lower = first)
        // But it doesn't matter since all rules must approve
        result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Still denied because both rules must approve
        assertFalse(result.approved);
        
        vm.stopPrank();
    }
    
    function test_RuleEvaluationAllApprove() public {
        vm.startPrank(owner);
        
        // Add only the allowing rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        
        // Test transfer evaluation - should approve
        IRules.RuleResult memory result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Check result - should be approved
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Test deposit evaluation - should approve
        result = rulesEngine.evaluateDeposit(
            address(0), alice, 100, alice
        );
        
        // Check result - should be approved
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        // Test withdraw evaluation - should approve
        result = rulesEngine.evaluateWithdraw(
            address(0), alice, 100, alice, alice
        );
        
        // Check result - should be approved
        assertTrue(result.approved);
        assertEq(result.reason, "");
        
        vm.stopPrank();
    }
    
    function test_InactiveRulesSkipped() public {
        vm.startPrank(owner);
        
        // Add a deny rule, then disable it
        denyRuleId = rulesEngine.addRule(address(denyRule), 100);
        rulesEngine.disableRule(denyRuleId);
        
        // Add an allow rule
        allowRuleId = rulesEngine.addRule(address(allowRule), 200);
        
        // Run evaluation, deny rule should be skipped
        IRules.RuleResult memory result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Only allow rule should be evaluated, so result is approved
        assertTrue(result.approved);
        
        // Re-enable deny rule
        rulesEngine.enableRule(denyRuleId);
        
        // Now deny rule will be evaluated, so result is denied
        result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        assertFalse(result.approved);
        
        vm.stopPrank();
    }
    
    function test_OperationSpecificRules() public {
        vm.startPrank(owner);
        
        // Add operation-specific rules
        transferRuleId = rulesEngine.addRule(address(transferRule), 100);
        depositRuleId = rulesEngine.addRule(address(depositRule), 100);
        withdrawRuleId = rulesEngine.addRule(address(withdrawRule), 100);
        
        // Test transfer - only transfer rule should apply
        IRules.RuleResult memory result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Transfer should be approved by the transfer rule
        assertTrue(result.approved);
        
        // Now add a deny rule for all operations
        denyRuleId = rulesEngine.addRule(address(denyRule), 50);  // Lower priority so it runs first
        
        // Test transfer again - should be denied by deny rule
        result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Should be denied
        assertFalse(result.approved);
        
        vm.stopPrank();
    }
    
    function test_NoRules() public {
        vm.startPrank(owner);
        
        // No rules added, everything should pass
        IRules.RuleResult memory result = rulesEngine.evaluateTransfer(
            address(0), alice, bob, 100
        );
        
        // Should be approved by default when no rules to check
        assertTrue(result.approved);
        
        vm.stopPrank();
    }
    
    function test_UnauthorizedRoleManagement() public {
        // Test rule management by non-owner
        vm.startPrank(alice);
        
        // Attempt to add a rule
        vm.expectRevert(); // Should fail with authorization error
        rulesEngine.addRule(address(allowRule), 100);
        
        vm.stopPrank();
        
        // Add a rule as owner
        vm.startPrank(owner);
        allowRuleId = rulesEngine.addRule(address(allowRule), 100);
        vm.stopPrank();
        
        // Attempt to disable a rule as non-owner
        vm.startPrank(alice);
        vm.expectRevert(); // Should fail with authorization error
        rulesEngine.disableRule(allowRuleId);
        vm.stopPrank();
    }
}

/**
 * @title MockRulesForOperation
 * @notice Mock rule implementation that only applies to specific operations
 */
contract MockRulesForOperation is MockRules {
    uint256 private _appliesTo;
    
    constructor(
        uint256 appliesTo_,
        bool initialApprove,
        string memory rejectReason
    ) MockRules(initialApprove, rejectReason) {
        _appliesTo = appliesTo_;
    }
    
    /// @notice Override the BaseRules appliesTo function
    function appliesTo() external view override returns (uint256) {
        return _appliesTo;
    }
}