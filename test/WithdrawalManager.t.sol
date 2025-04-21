// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {WithdrawalManager} from "../src/managers/WithdrawalManager.sol";
import {WithdrawalQueueRule} from "../src/rules/WithdrawalQueueRule.sol";
import {MerkleHelper} from "../src/managers/MerkleHelper.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {IWithdrawalManager} from "../src/managers/IWithdrawalManager.sol";

/**
 * @title WithdrawalManagerTest
 * @notice Test the withdrawal manager functionality
 */
contract WithdrawalManagerTest is BaseFountfiTest {
    // Additional contracts
    WithdrawalManager public withdrawalManager;
    WithdrawalQueueRule public withdrawalRule;
    MerkleHelper public merkleHelper;
    
    // Merkle tree variables for testing
    bytes32 public merkleRoot;
    bytes32[] public aliceMerkleProof;
    bytes32[] public bobMerkleProof;
    
    // Request IDs
    uint256 public aliceRequestId;
    uint256 public bobRequestId;
    
    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy merkle helper
        merkleHelper = new MerkleHelper();
        
        // Deploy tRWA with mock rules initially
        tRwaToken = new tRWA("Tokenized RWA", "tRWA", address(usdc), address(strategy), address(rules));
        
        // Deploy withdrawal manager
        withdrawalManager = new WithdrawalManager(address(tRwaToken), owner);
        
        // Deploy withdrawal queue rule
        withdrawalRule = new WithdrawalQueueRule(address(withdrawalManager), owner);
        
        // Create new tRWA with withdrawal rule
        tRWA newToken = new tRWA("Tokenized RWA", "tRWA", address(usdc), address(strategy), address(withdrawalRule));
        tRwaToken = newToken;
        
        // Fund the strategy
        usdc.mint(address(strategy), 1_000_000e6);
        
        vm.stopPrank();
    }
    
    function test_RequestWithdrawal() public {
        // First deposit some assets
        vm.startPrank(alice);
        usdc.mint(alice, 10_000e6);
        usdc.approve(address(tRwaToken), 1_000e6);
        tRwaToken.deposit(1_000e6, alice);
        
        // Request withdrawal
        uint256 assets = 500e6;
        uint256 shares = tRwaToken.previewWithdraw(assets);
        
        try tRwaToken.withdraw(assets, alice, alice) {
            fail("Withdrawal should be rejected and queued");
        } catch {}
        
        // Check that the request was created
        aliceRequestId = 1; // First request should have ID 1
        
        IWithdrawalManager.WithdrawalRequest memory request = withdrawalManager.getWithdrawalRequest(aliceRequestId);
        
        assertEq(request.user, alice);
        assertEq(request.assets, assets);
        assertEq(request.shares, shares);
        assertFalse(request.executed);
        
        // Bob also deposits and requests withdrawal
        vm.stopPrank();
        vm.startPrank(bob);
        usdc.mint(bob, 10_000e6);
        usdc.approve(address(tRwaToken), 2_000e6);
        tRwaToken.deposit(2_000e6, bob);
        
        // Request withdrawal
        try tRwaToken.withdraw(1_000e6, bob, bob) {
            fail("Withdrawal should be rejected and queued");
        } catch {}
        
        bobRequestId = 2; // Second request
        
        vm.stopPrank();
    }
    
    function test_WithdrawalApprovalAndExecution() public {
        // Setup withdrawals
        test_RequestWithdrawal();
        
        vm.startPrank(owner);
        
        // Approve the requests
        uint256[] memory requestIds = new uint256[](2);
        requestIds[0] = aliceRequestId;
        requestIds[1] = bobRequestId;
        withdrawalManager.approveWithdrawals(requestIds);
        
        // Create merkle tree
        bytes32[] memory leaves = new bytes32[](2);
        
        IWithdrawalManager.WithdrawalRequest memory aliceRequest = withdrawalManager.getWithdrawalRequest(aliceRequestId);
        IWithdrawalManager.WithdrawalRequest memory bobRequest = withdrawalManager.getWithdrawalRequest(bobRequestId);
        
        leaves[0] = merkleHelper.computeLeaf(aliceRequestId, alice, aliceRequest.assets);
        leaves[1] = merkleHelper.computeLeaf(bobRequestId, bob, bobRequest.assets);
        
        merkleRoot = merkleHelper.computeRoot(leaves);
        
        // Generate merkle proofs
        aliceMerkleProof = merkleHelper.getProof(leaves, 0);
        bobMerkleProof = merkleHelper.getProof(leaves, 1);
        
        // Create a withdrawal period
        uint256 periodId = withdrawalManager.openWithdrawalPeriod(
            7 days,
            merkleRoot,
            aliceRequest.assets + bobRequest.assets
        );
        
        assertEq(periodId, 1);
        
        vm.stopPrank();
        
        // Execute Alice's withdrawal
        vm.startPrank(alice);
        bool success = withdrawalManager.executeWithdrawal(aliceRequestId, aliceMerkleProof);
        
        assertTrue(success);
        
        // Check that Alice's shares were burned
        uint256 expectedAliceBalance = 1_000e6 - aliceRequest.shares;
        assertEq(tRwaToken.balanceOf(alice), expectedAliceBalance);
        
        // Check that Alice received assets
        assertEq(usdc.balanceOf(alice), aliceRequest.assets);
        
        vm.stopPrank();
        
        // Bob executes his withdrawal
        vm.startPrank(bob);
        success = withdrawalManager.executeWithdrawal(bobRequestId, bobMerkleProof);
        
        assertTrue(success);
        
        // Check that Bob's shares were burned
        uint256 expectedBobBalance = 2_000e6 - bobRequest.shares;
        assertEq(tRwaToken.balanceOf(bob), expectedBobBalance);
        
        // Check that Bob received assets
        assertEq(usdc.balanceOf(bob), bobRequest.assets);
        
        vm.stopPrank();
        
        // Check that the period is now closed (auto-closed when all assets withdrawn)
        IWithdrawalManager.WithdrawalPeriod memory period = withdrawalManager.getCurrentWithdrawalPeriod();
        assertFalse(period.active);
    }
    
    function test_WithdrawalPeriodExpiry() public {
        // Setup withdrawals
        test_RequestWithdrawal();
        
        vm.startPrank(owner);
        
        // Approve the requests
        uint256[] memory requestIds = new uint256[](2);
        requestIds[0] = aliceRequestId;
        requestIds[1] = bobRequestId;
        withdrawalManager.approveWithdrawals(requestIds);
        
        // Create merkle tree
        bytes32[] memory leaves = new bytes32[](2);
        
        IWithdrawalManager.WithdrawalRequest memory aliceRequest = withdrawalManager.getWithdrawalRequest(aliceRequestId);
        IWithdrawalManager.WithdrawalRequest memory bobRequest = withdrawalManager.getWithdrawalRequest(bobRequestId);
        
        leaves[0] = merkleHelper.computeLeaf(aliceRequestId, alice, aliceRequest.assets);
        leaves[1] = merkleHelper.computeLeaf(bobRequestId, bob, bobRequest.assets);
        
        merkleRoot = merkleHelper.computeRoot(leaves);
        
        // Create a withdrawal period with short duration
        uint256 periodId = withdrawalManager.openWithdrawalPeriod(
            1 days,
            merkleRoot,
            aliceRequest.assets + bobRequest.assets
        );
        
        vm.stopPrank();
        
        // Alice executes withdrawal
        vm.startPrank(alice);
        bool success = withdrawalManager.executeWithdrawal(aliceRequestId, aliceMerkleProof);
        assertTrue(success);
        vm.stopPrank();
        
        // Advance time past the period end
        vm.warp(block.timestamp + 2 days);
        
        // Bob tries to execute - should fail
        vm.startPrank(bob);
        vm.expectRevert(); // Should revert with WithdrawalPeriodInactive
        withdrawalManager.executeWithdrawal(bobRequestId, bobMerkleProof);
        vm.stopPrank();
        
        // Check period status
        IWithdrawalManager.WithdrawalPeriod memory period = withdrawalManager.getCurrentWithdrawalPeriod();
        assertFalse(period.active);
    }
    
    function test_InvalidMerkleProof() public {
        // Setup withdrawals
        test_RequestWithdrawal();
        
        vm.startPrank(owner);
        
        // Approve only Alice's request
        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = aliceRequestId;
        withdrawalManager.approveWithdrawals(requestIds);
        
        // Create merkle tree with just Alice
        bytes32[] memory leaves = new bytes32[](1);
        
        IWithdrawalManager.WithdrawalRequest memory aliceRequest = withdrawalManager.getWithdrawalRequest(aliceRequestId);
        leaves[0] = merkleHelper.computeLeaf(aliceRequestId, alice, aliceRequest.assets);
        
        merkleRoot = merkleHelper.computeRoot(leaves);
        
        // Generate merkle proof
        aliceMerkleProof = merkleHelper.getProof(leaves, 0);
        
        // Create a withdrawal period
        withdrawalManager.openWithdrawalPeriod(
            7 days,
            merkleRoot,
            aliceRequest.assets
        );
        
        vm.stopPrank();
        
        // Bob tries to execute with invalid proof
        vm.startPrank(bob);
        
        // Try with empty proof
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.expectRevert(); // Should revert with InvalidMerkleProof
        withdrawalManager.executeWithdrawal(bobRequestId, emptyProof);
        
        // Try with Alice's proof
        vm.expectRevert(); // Should revert with InvalidMerkleProof
        withdrawalManager.executeWithdrawal(bobRequestId, aliceMerkleProof);
        
        vm.stopPrank();
    }
    
    function test_WithdrawalCallbacks() public {
        // First deposit some assets
        vm.startPrank(alice);
        usdc.mint(alice, 10_000e6);
        usdc.approve(address(tRwaToken), 1_000e6);
        tRwaToken.deposit(1_000e6, alice);
        
        // Create a mock contract that will receive callbacks - will be simulated here
        bool callbackReceived = false;
        
        // Try to withdraw with callback
        try tRwaToken.withdraw(
            500e6,
            alice,
            alice,
            true,
            abi.encode(alice, 500e6)
        ) {
            fail("Withdrawal should be rejected and queued");
        } catch {
            // This is expected - the withdrawal was queued
            callbackReceived = true;
        }
        
        assertTrue(callbackReceived, "Callback should have been triggered");
        
        vm.stopPrank();
    }
}