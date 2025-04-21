// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {SubscriptionManager} from "../src/managers/SubscriptionManager.sol";
import {SubscriptionRules} from "../src/rules/SubscriptionRules.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {ISubscriptionManager} from "../src/managers/ISubscriptionManager.sol";

/**
 * @title SubscriptionManagerTest
 * @notice Test the subscription manager functionality
 */
contract SubscriptionManagerTest is BaseFountfiTest {
    // Additional contracts
    SubscriptionManager public subscriptionManager;
    SubscriptionRules public subscriptionRules;
    
    // Constants
    uint256 public constant SUB_AMOUNT = 100e6;
    uint256 public constant SUB_FREQUENCY = 30 days;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy subscription rules
        subscriptionRules = new SubscriptionRules(owner, true, true);
        
        // Create tRWA with subscription rules
        tRwaToken = new tRWA("Tokenized RWA", "tRWA", address(usdc), address(strategy), address(subscriptionRules));
        
        // Deploy subscription manager
        subscriptionManager = new SubscriptionManager(
            address(tRwaToken),
            owner,
            address(subscriptionRules),
            owner, // fee recipient
            200, // 2% subscription fee
            100  // 1% withdrawal fee
        );
        
        // Grant subscription manager role to manage subscriptions
        subscriptionRules.grantRole(address(subscriptionManager), 1); // SUBSCRIPTION_MANAGER_ROLE = 1 << 0
        
        // Fund the strategy
        usdc.mint(address(strategy), 1_000_000e6);
        
        vm.stopPrank();
    }
    
    function test_CreateSubscription() public {
        vm.startPrank(alice);
        
        // Create a subscription
        bytes memory metadata = abi.encode("Alice Subscription");
        uint256 subscriptionId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            metadata
        );
        
        // Verify subscription was created
        ISubscriptionManager.Subscription memory sub = subscriptionManager.getSubscription(subscriptionId);
        
        assertEq(sub.id, subscriptionId);
        assertEq(sub.user, alice);
        assertEq(sub.amount, SUB_AMOUNT);
        assertEq(sub.frequency, SUB_FREQUENCY);
        assertTrue(sub.active);
        
        // Check that user was added to subscription rules
        assertTrue(subscriptionRules.isSubscriptionApproved(alice));
        
        // Verify user subscription list
        uint256[] memory userSubs = subscriptionManager.getUserSubscriptions(alice);
        assertEq(userSubs.length, 1);
        assertEq(userSubs[0], subscriptionId);
        
        vm.stopPrank();
    }
    
    function test_ProcessPayment() public {
        // Create subscription
        vm.startPrank(alice);
        bytes memory metadata = abi.encode("Alice Subscription");
        uint256 subscriptionId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            metadata
        );
        
        // Provide funds for payment
        usdc.mint(alice, 10_000e6);
        usdc.approve(address(subscriptionManager), SUB_AMOUNT);
        
        // Fast forward to payment due date
        uint256 nextPaymentDue = block.timestamp + SUB_FREQUENCY;
        vm.warp(nextPaymentDue);
        
        vm.stopPrank();
        
        // Process payment
        vm.startPrank(owner);
        bool success = subscriptionManager.processPayment(subscriptionId);
        
        assertTrue(success);
        
        // Check payment was processed
        ISubscriptionManager.Subscription memory sub = subscriptionManager.getSubscription(subscriptionId);
        assertEq(sub.nextPaymentDue, nextPaymentDue + SUB_FREQUENCY);
        
        // Check fee distribution
        uint256 fee = (SUB_AMOUNT * 200) / 10000; // 2%
        uint256 netAmount = SUB_AMOUNT - fee;
        
        assertEq(usdc.balanceOf(owner), fee); // Fee recipient receives fee
        assertEq(usdc.balanceOf(address(strategy)), netAmount); // Strategy receives net amount
        
        vm.stopPrank();
    }
    
    function test_CancelSubscription() public {
        // Create subscription
        vm.startPrank(alice);
        bytes memory metadata = abi.encode("Alice Subscription");
        uint256 subscriptionId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            metadata
        );
        
        // Cancel subscription
        subscriptionManager.cancelSubscription(subscriptionId);
        
        // Verify subscription is inactive
        ISubscriptionManager.Subscription memory sub = subscriptionManager.getSubscription(subscriptionId);
        assertFalse(sub.active);
        
        // Fast forward to payment due date
        vm.warp(block.timestamp + SUB_FREQUENCY);
        
        // Try to process payment - should fail
        vm.stopPrank();
        vm.startPrank(owner);
        vm.expectRevert(); // Should revert with InactiveSubscription
        subscriptionManager.processPayment(subscriptionId);
        
        vm.stopPrank();
    }
    
    function test_SubscriptionRound() public {
        vm.startPrank(owner);
        
        // Open a subscription round
        uint256 roundId = subscriptionManager.openSubscriptionRound(
            "First Round",
            block.timestamp,
            block.timestamp + 30 days,
            100
        );
        
        // Verify round was created
        ISubscriptionManager.SubscriptionRound memory round = subscriptionManager.getCurrentRound();
        
        assertEq(round.id, roundId);
        assertEq(round.name, "First Round");
        assertEq(round.subscriptionCount, 0);
        assertTrue(round.active);
        
        // Create a few subscriptions
        vm.stopPrank();
        
        vm.startPrank(alice);
        subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            abi.encode("Alice Subscription")
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        subscriptionManager.createSubscription(
            bob,
            SUB_AMOUNT * 2,
            SUB_FREQUENCY,
            abi.encode("Bob Subscription")
        );
        vm.stopPrank();
        
        // Close the round
        vm.startPrank(owner);
        subscriptionManager.closeSubscriptionRound();
        
        // Verify round is closed
        round = subscriptionManager.getCurrentRound();
        assertFalse(round.active);
        
        // Check subscription status is closed
        assertFalse(subscriptionRules.isOpen());
        
        vm.stopPrank();
    }
    
    function test_BatchProcessPayments() public {
        // Create multiple subscriptions
        vm.startPrank(alice);
        uint256 aliceSubId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            abi.encode("Alice Subscription")
        );
        usdc.mint(alice, 10_000e6);
        usdc.approve(address(subscriptionManager), SUB_AMOUNT * 10);
        vm.stopPrank();
        
        vm.startPrank(bob);
        uint256 bobSubId = subscriptionManager.createSubscription(
            bob,
            SUB_AMOUNT * 2,
            SUB_FREQUENCY,
            abi.encode("Bob Subscription")
        );
        usdc.mint(bob, 10_000e6);
        usdc.approve(address(subscriptionManager), SUB_AMOUNT * 20);
        vm.stopPrank();
        
        // Fast forward to payment due date
        vm.warp(block.timestamp + SUB_FREQUENCY);
        
        // Process payments in batch
        vm.startPrank(owner);
        uint256[] memory subscriptionIds = new uint256[](2);
        subscriptionIds[0] = aliceSubId;
        subscriptionIds[1] = bobSubId;
        
        uint256 successCount = subscriptionManager.batchProcessPayments(subscriptionIds);
        
        assertEq(successCount, 2);
        
        // Verify next payment dates
        ISubscriptionManager.Subscription memory aliceSub = subscriptionManager.getSubscription(aliceSubId);
        ISubscriptionManager.Subscription memory bobSub = subscriptionManager.getSubscription(bobSubId);
        
        assertEq(aliceSub.nextPaymentDue, block.timestamp + SUB_FREQUENCY);
        assertEq(bobSub.nextPaymentDue, block.timestamp + SUB_FREQUENCY);
        
        vm.stopPrank();
    }
    
    function test_UpdateSubscription() public {
        // Create subscription
        vm.startPrank(alice);
        uint256 subscriptionId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            abi.encode("Alice Subscription")
        );
        vm.stopPrank();
        
        // Update subscription
        vm.startPrank(owner);
        uint256 newAmount = SUB_AMOUNT * 2;
        uint256 newFrequency = SUB_FREQUENCY / 2;
        bytes memory newMetadata = abi.encode("Updated Alice Subscription");
        
        subscriptionManager.updateSubscription(
            subscriptionId,
            newAmount,
            newFrequency,
            newMetadata
        );
        
        // Verify updates
        ISubscriptionManager.Subscription memory sub = subscriptionManager.getSubscription(subscriptionId);
        
        assertEq(sub.amount, newAmount);
        assertEq(sub.frequency, newFrequency);
        assertEq(keccak256(sub.metadata), keccak256(newMetadata));
        
        vm.stopPrank();
    }
    
    function test_PaymentCallbacks() public {
        // Create subscription with callback support
        vm.startPrank(alice);
        bytes memory metadata = abi.encode("Alice Subscription");
        uint256 subscriptionId = subscriptionManager.createSubscription(
            alice,
            SUB_AMOUNT,
            SUB_FREQUENCY,
            metadata
        );
        
        // Fund the account
        usdc.mint(alice, 10_000e6);
        usdc.approve(address(tRwaToken), 500e6);
        
        // Deposit with callback
        bool callbackReceived = false;
        
        try tRwaToken.deposit(
            500e6,
            alice,
            true,
            abi.encode(subscriptionId, alice)
        ) returns (uint256 shares) {
            callbackReceived = true;
            assertGt(shares, 0);
        } catch {
            fail("Deposit with callback should succeed");
        }
        
        assertTrue(callbackReceived, "Callback should have been received");
        
        vm.stopPrank();
    }
}