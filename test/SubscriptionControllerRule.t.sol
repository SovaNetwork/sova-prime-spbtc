// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {SubscriptionController} from "../src/controllers/SubscriptionController.sol";
import {ISubscriptionController} from "../src/controllers/ISubscriptionController.sol";
import {SubscriptionControllerRule} from "../src/rules/SubscriptionControllerRule.sol";
import {IRules} from "../src/rules/IRules.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {RulesEngine} from "../src/rules/RulesEngine.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";

/**
 * @title SubscriptionControllerRuleTest
 * @notice Tests for the SubscriptionControllerRule
 */
contract SubscriptionControllerRuleTest is BaseFountfiTest {
    // Test contracts
    SubscriptionController public controller;
    SubscriptionControllerRule public controllerRule;
    tRWA public token;
    MockStrategy public strategy;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy a mock tRWA setup - this is done with owner in the BaseFountfiTest.deployMockTRWA method
        (strategy, token) = deployMockTRWA("Test Token", "TT");
        
        vm.startPrank(owner);
        
        // Create additional admin addresses
        address[] memory managers = new address[](1);
        managers[0] = admin;
        
        // Deploy subscription controller
        controller = new SubscriptionController(
            address(token),
            owner,
            managers
        );
        
        // Deploy controller rule
        controllerRule = new SubscriptionControllerRule(address(controller));
        
        vm.stopPrank();
    }
    
    function test_Constructor() public {
        // Verify controller reference
        assertEq(address(controllerRule.controller()), address(controller), "Controller address mismatch");
        
        // Verify constructor reverts with zero address
        vm.startPrank(owner);
        vm.expectRevert(SubscriptionControllerRule.InvalidController.selector);
        new SubscriptionControllerRule(address(0));
        vm.stopPrank();
    }
    
    function test_AppliesTo() public {
        // The rule should only apply to deposits (0x2)
        assertEq(controllerRule.appliesTo(), 0x2, "Rule should only apply to deposits");
    }
    
    function test_EvaluateDeposit_WithoutActiveRound() public {
        vm.startPrank(owner);
        
        // Evaluate deposit without an active round
        IRules.RuleResult memory result = controllerRule.evaluateDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        
        // Verify result (should be rejected)
        assertFalse(result.approved, "Deposit should be rejected without active round");
        assertEq(result.reason, "No active subscription round", "Rejection reason mismatch");
        
        vm.stopPrank();
    }
    
    function test_EvaluateDeposit_WithActiveRound() public {
        vm.startPrank(owner);
        
        // Open a subscription round
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            100
        );
        
        // Evaluate deposit with active round
        IRules.RuleResult memory result = controllerRule.evaluateDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        
        // Verify result (should be approved)
        assertTrue(result.approved, "Deposit should be approved with active round");
        assertEq(result.reason, "", "Approval reason should be empty");
        
        vm.stopPrank();
    }
    
    function test_EvaluateDeposit_RoundFull() public {
        vm.startPrank(owner);
        
        // Open a subscription round with capacity 1
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            1
        );
        
        // Simulate a deposit via callback
        vm.stopPrank();
        vm.startPrank(address(token));
        controller.operationCallback(
            keccak256("DEPOSIT"),
            true,
            abi.encode(alice, 1000 * 1e6)
        );
        vm.stopPrank();
        
        // Now try to evaluate another deposit
        vm.startPrank(owner);
        IRules.RuleResult memory result = controllerRule.evaluateDeposit(
            address(token),
            bob,
            1000 * 1e6,
            bob
        );
        
        // Verify result (should be rejected due to capacity)
        assertFalse(result.approved, "Deposit should be rejected when round is full");
        assertEq(result.reason, "Subscription round capacity reached", "Rejection reason mismatch");
        
        vm.stopPrank();
    }
    
    function test_EvaluateDeposit_ExpiredRound() public {
        vm.startPrank(owner);
        
        // Open a subscription round
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            100
        );
        
        // Fast forward past end time
        vm.warp(block.timestamp + 8 days);
        
        // Evaluate deposit with expired round
        IRules.RuleResult memory result = controllerRule.evaluateDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        
        // Verify result (should be rejected)
        assertFalse(result.approved, "Deposit should be rejected with expired round");
        assertEq(result.reason, "Subscription round not active or expired", "Rejection reason mismatch");
        
        vm.stopPrank();
    }
    
    function test_RulesEngine_Integration() public {
        vm.startPrank(owner);
        
        // Open a subscription round
        controller.openSubscriptionRound(
            "Round 1",
            block.timestamp,
            block.timestamp + 7 days,
            100
        );
        
        // Get direct evaluation from the controller rule
        IRules.RuleResult memory result = controllerRule.evaluateDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        
        // Verify result (should be approved)
        assertTrue(result.approved, "Deposit should be approved with active round");
        assertEq(result.reason, "", "Approval reason should be empty");
        
        // Now close the round
        controller.closeSubscriptionRound();
        
        // Re-evaluate deposit after closing round
        result = controllerRule.evaluateDeposit(
            address(token),
            alice,
            1000 * 1e6,
            alice
        );
        
        // Verify result (should be rejected)
        assertFalse(result.approved, "Deposit should be rejected after round closed");
        assertEq(result.reason, "Subscription round not active or expired", "Rejection reason mismatch");
        
        vm.stopPrank();
    }
}