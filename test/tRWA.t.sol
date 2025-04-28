// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockRules} from "../src/mocks/MockRules.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockRoleManager} from "../src/mocks/MockRoleManager.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {ICallbackReceiver} from "../src/token/tRWA.sol";
import {IRules} from "../src/rules/IRules.sol";
import {Registry} from "../src/registry/Registry.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Mock callback receiver for testing callback functionality
contract MockCallbackReceiver is ICallbackReceiver {
    bool public callbackReceived;
    bytes32 public lastOperationType;
    bool public lastSuccess;
    bytes public lastData;
    bool public shouldRevert;

    function operationCallback(
        bytes32 operationType,
        bool success,
        bytes memory data
    ) external override {
        if (shouldRevert) {
            revert("Callback revert");
        }
        callbackReceived = true;
        lastOperationType = operationType;
        lastSuccess = success;
        lastData = data;
    }

    function resetState() external {
        callbackReceived = false;
        lastOperationType = bytes32(0);
        lastSuccess = false;
        lastData = "";
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
}

// Mock rules that enables control over withdrawal responses
contract WithdrawQueueMockRules is MockRules {
    bool public withdrawalsQueued = false;

    constructor(bool initialApprove, string memory rejectReason)
        MockRules(initialApprove, rejectReason)
    {}

    function setWithdrawalsQueued(bool queued) external {
        withdrawalsQueued = queued;
    }

    function evaluateWithdraw(
        address token,
        address caller,
        uint256 amount,
        address recipient,
        address owner
    ) public view virtual override returns (IRules.RuleResult memory) {
        if (withdrawalsQueued) {
            return IRules.RuleResult({
                approved: false,
                reason: "Direct withdrawals not supported. Withdrawal request created in queue."
            });
        }
        return super.evaluateWithdraw(token, caller, amount, recipient, owner);
    }
}

/**
 * @title TRWATest
 * @notice Comprehensive tests for tRWA contract to achieve 100% coverage
 */
contract TRWATest is BaseFountfiTest {
    // Test-specific contracts
    tRWA internal token;
    MockStrategy internal strategy;
    WithdrawQueueMockRules internal queueRules;
    MockCallbackReceiver internal callbackReceiver;

    // Test constants
    uint256 internal constant INITIAL_DEPOSIT = 1000 * 10**6; // 1000 USDC
    
    // Helper to set allowances and deposit USDC to a tRWA token and update MockStrategy balance
    function depositTRWA(address user, address trwaToken, uint256 assets) internal override returns (uint256) {
        // First update MockStrategy balance to properly handle deposits
        vm.prank(owner);
        strategy.setBalance(assets);
        
        // Add a 1 wei deposit first to initialize the ERC4626 vault
        // This helps with the virtual shares protection
        vm.startPrank(owner);
        usdc.mint(owner, 1);
        usdc.approve(trwaToken, 1);
        tRWA(trwaToken).deposit(1, owner);
        vm.stopPrank();
        
        // Now do the actual deposit
        vm.startPrank(user);
        usdc.approve(trwaToken, assets);
        uint256 shares = tRWA(trwaToken).deposit(assets, user);
        vm.stopPrank();
        return shares;
    }
    
    function setUp() public override {
        // Call parent setup
        super.setUp();
        
        // Deploy specialized mock rules for testing withdrawals
        queueRules = new WithdrawQueueMockRules(true, "Test rejection");
        
        vm.startPrank(owner);
        
        // Deploy a fresh strategy with MockRules
        strategy = new MockStrategy(owner);
        strategy.initialize(
            "Tokenized RWA",
            "tRWA",
            manager,
            address(usdc),
            address(queueRules),
            ""
        );
        
        // Get the token the strategy created
        token = tRWA(strategy.sToken());
        
        // Setup callback receiver
        callbackReceiver = new MockCallbackReceiver();
        
        // Since we're the owner, we can mint tokens freely
        usdc.mint(alice, 10_000 * 10**6);
        usdc.mint(bob, 10_000 * 10**6);
        usdc.mint(manager, 10_000 * 10**6);
        usdc.mint(address(this), 10_000 * 10**6);
        
        vm.stopPrank();
        
        // Set initial balance for alice
        vm.startPrank(alice);
        usdc.approve(address(token), type(uint256).max);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Constructor() public {
        // Test token properties
        assertEq(token.name(), "Tokenized RWA");
        assertEq(token.symbol(), "tRWA");
        assertEq(token.decimals(), 18);
        assertEq(token.asset(), address(usdc));
        
        // Test internal references
        assertEq(address(token.strategy()), address(strategy));
        assertEq(address(token.rules()), address(queueRules));
    }
    
    function test_Constructor_Reverts_WithInvalidAddresses() public {
        vm.startPrank(owner);
        
        // Test invalid asset address
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        new tRWA("Test", "TEST", address(0), address(strategy), address(queueRules));
        
        // Test invalid strategy address
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        new tRWA("Test", "TEST", address(usdc), address(0), address(queueRules));
        
        // Test invalid rules address
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        new tRWA("Test", "TEST", address(usdc), address(strategy), address(0));
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                         CONTROLLER TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_SetController() public {
        // Token was created by strategy which should set the controller
        // Let's verify it's correctly initialized
        vm.prank(address(strategy));
        token.setController(address(callbackReceiver));
        
        assertEq(token.controller(), address(callbackReceiver));
    }
    
    function test_SetController_Reverts_WhenCalledByNonStrategy() public {
        vm.expectRevert(abi.encodeWithSignature("tRWAUnauthorized(address,address)", address(this), address(strategy)));
        token.setController(address(callbackReceiver));
    }
    
    function test_SetController_Reverts_WhenAlreadySet() public {
        // Set controller first time
        vm.prank(address(strategy));
        token.setController(address(callbackReceiver));
        
        // Try to set it again
        vm.prank(address(strategy));
        vm.expectRevert(abi.encodeWithSignature("ControllerAlreadySet()"));
        token.setController(address(alice));
    }
    
    function test_SetController_Reverts_WithInvalidAddress() public {
        vm.prank(address(strategy));
        vm.expectRevert(abi.encodeWithSignature("InvalidAddress()"));
        token.setController(address(0));
    }
    
    /*//////////////////////////////////////////////////////////////
                          ERC4626 BASIC TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Asset() public {
        assertEq(token.asset(), address(usdc));
    }
    
    function test_TotalAssets() public {
        // Initially zero
        assertEq(token.totalAssets(), 0);
        
        // After deposit, should reflect strategy balance
        depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        assertEq(token.totalAssets(), INITIAL_DEPOSIT);
    }
    
    function test_Deposit() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1);
        usdc.approve(address(token), 1);
        strategy.setBalance(1);
        token.deposit(1, owner);
        vm.stopPrank();
        
        // Now do a real deposit
        vm.startPrank(alice);
        
        // Prepare strategy with actual balance
        vm.stopPrank();
        vm.prank(owner);
        strategy.setBalance(strategy.balance() + INITIAL_DEPOSIT);
        
        // Deposit as alice
        vm.startPrank(alice);
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, alice);
        vm.stopPrank();
        
        // First deposit with virtual shares protection, shares might not equal assets 
        // due to the inflation protection in ERC4626
        assertEq(token.balanceOf(alice), shares);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - INITIAL_DEPOSIT);
        
        // Check asset accounting (with virtual shares tolerance)
        assertApproxEqAbs(token.totalAssets(), INITIAL_DEPOSIT + 1, 10); // +1 for the initial deposit
        
        // The share calculation with virtual shares protection might not be 1:1,
        // verify that the virtual assets are still close
        uint256 virtualAssets = token.convertToAssets(shares);
        assertApproxEqRel(virtualAssets, INITIAL_DEPOSIT, 1e16); // 1% tolerance
    }
    
    function test_Deposit_WithCallback() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1);
        usdc.approve(address(token), 1);
        strategy.setBalance(1);
        token.deposit(1, owner);
        
        // Mint tokens to callback receiver contract
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Update strategy balance to handle deposit
        strategy.setBalance(strategy.balance() + INITIAL_DEPOSIT);
        vm.stopPrank();
        
        vm.startPrank(address(callbackReceiver));
        
        // Approve tokens
        usdc.approve(address(token), INITIAL_DEPOSIT);
        
        // Deposit with callback
        uint256 shares = token.deposit(
            INITIAL_DEPOSIT,
            address(callbackReceiver),
            true,
            ""
        );
        
        vm.stopPrank();
        
        // Check callback was received
        assertTrue(callbackReceiver.callbackReceived());
        assertEq(callbackReceiver.lastOperationType(), keccak256("DEPOSIT"));
        assertTrue(callbackReceiver.lastSuccess());
        
        // Check balances
        assertEq(token.balanceOf(address(callbackReceiver)), shares);
    }
    
    function test_Deposit_WithCallbackRevert() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1);
        usdc.approve(address(token), 1);
        strategy.setBalance(1);
        token.deposit(1, owner);
        
        // Mint tokens to callback receiver contract
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Update strategy balance to handle deposit
        strategy.setBalance(strategy.balance() + INITIAL_DEPOSIT);
        vm.stopPrank();
        
        vm.startPrank(address(callbackReceiver));
        
        // Set callback to revert
        callbackReceiver.setShouldRevert(true);
        
        // Approve tokens
        usdc.approve(address(token), INITIAL_DEPOSIT);
        
        // Deposit should succeed even if callback reverts
        uint256 shares = token.deposit(
            INITIAL_DEPOSIT,
            address(callbackReceiver),
            true,
            ""
        );
        
        vm.stopPrank();
        
        // Check balances - deposit should succeed despite callback failure
        assertEq(token.balanceOf(address(callbackReceiver)), shares);
    }
    
    function test_Deposit_WithControllerCallback() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1);
        usdc.approve(address(token), 1);
        strategy.setBalance(1);
        token.deposit(1, owner);
        vm.stopPrank();
        
        // Set controller
        vm.prank(address(strategy));
        token.setController(address(callbackReceiver));
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Update strategy and prepare for deposit
        vm.prank(owner);
        strategy.setBalance(strategy.balance() + INITIAL_DEPOSIT);
        
        // Deposit tokens (should trigger controller callback)
        vm.startPrank(alice);
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, alice);
        vm.stopPrank();
        
        // Check callback was received
        assertTrue(callbackReceiver.callbackReceived());
        assertEq(callbackReceiver.lastOperationType(), keccak256("DEPOSIT"));
        assertTrue(callbackReceiver.lastSuccess());
        
        // Check encoded data
        (address receiver, uint256 assets) = abi.decode(callbackReceiver.lastData(), (address, uint256));
        assertEq(receiver, alice);
        assertEq(assets, INITIAL_DEPOSIT);
        
        // Check balances
        assertEq(token.balanceOf(alice), shares);
    }
    
    function test_Deposit_FailsWhenRulesReject() public {
        // Set rules to reject
        queueRules.setApproveStatus(false, "Test rejection");
        
        // Try to deposit
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Test rejection"));
        token.deposit(INITIAL_DEPOSIT, alice);
    }
    
    function test_Mint() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1000); // Slightly larger initial deposit
        usdc.approve(address(token), 1000);
        strategy.setBalance(1000);
        token.deposit(1000, owner);
        vm.stopPrank();
        
        // Calculate assets needed for desired shares - use a smaller value
        uint256 desiredShares = 100 * 10**6; // 100 tokens with same decimals as USDC
        
        // Setup strategy to allow minting
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT * 2); // Prepare for mint
        
        // Preview how many assets will be needed - should be approximately equal to shares
        uint256 assetsNeeded = token.previewMint(desiredShares);
        
        // Mint tokens
        vm.startPrank(alice);
        usdc.approve(address(token), assetsNeeded);
        uint256 assets = token.mint(desiredShares, alice);
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(alice), desiredShares, "Share balance does not match requested amount");
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - assets, "USDC balance not reduced correctly");
        
        // Asset/share conversion may not be exactly 1:1 due to virtual shares mechanism
        // But with a properly initialized vault, should be close
        uint256 virtualAssets = token.convertToAssets(desiredShares);
        assertApproxEqRel(virtualAssets, assets, 1e16, "Asset conversion doesn't match expected value"); // 1% tolerance
    }
    
    function test_Mint_WithCallback() public {
        // Do a small deposit first to initialize the ERC4626 vault
        vm.startPrank(owner);
        usdc.mint(owner, 1000); // Slightly larger initial deposit
        usdc.approve(address(token), 1000);
        strategy.setBalance(1000);
        token.deposit(1000, owner);
        vm.stopPrank();
        
        // Calculate assets needed for desired shares - use a smaller value
        uint256 desiredShares = 100 * 10**6; // 100 tokens with same decimals as USDC
        
        // Setup strategy to allow minting
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT * 2); // Prepare for mint
        
        // Preview how many assets will be needed - should be approximately equal to shares
        uint256 assetsNeeded = token.previewMint(desiredShares);
        
        // Mint tokens to callback receiver contract
        vm.startPrank(owner);
        usdc.mint(address(callbackReceiver), assetsNeeded);
        vm.stopPrank();
        
        vm.startPrank(address(callbackReceiver));
        
        // Approve tokens
        usdc.approve(address(token), assetsNeeded);
        
        // Mint with callback
        uint256 assets = token.mint(
            desiredShares,
            address(callbackReceiver),
            true,
            ""
        );
        
        vm.stopPrank();
        
        // Check callback was received
        assertTrue(callbackReceiver.callbackReceived(), "Callback was not received");
        assertEq(callbackReceiver.lastOperationType(), keccak256("MINT"), "Operation type incorrect");
        assertTrue(callbackReceiver.lastSuccess(), "Callback was not successful");
        
        // Check balances - shares match exactly as requested
        assertEq(token.balanceOf(address(callbackReceiver)), desiredShares, "Share balance does not match");
        
        // Asset/share conversion may not be exactly 1:1 due to virtual shares mechanism
        uint256 virtualAssets = token.convertToAssets(desiredShares);
        assertApproxEqRel(virtualAssets, assets, 1e16, "Asset conversion doesn't match"); // 1% tolerance
    }
    
    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL TESTS (DIRECT)
    //////////////////////////////////////////////////////////////*/
    
    function test_Withdraw() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Then withdraw half
        uint256 withdrawAmount = INITIAL_DEPOSIT / 2;
        
        // Update strategy balance to have assets for withdrawal
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        vm.startPrank(alice);
        uint256 sharesRedeemed = token.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();
        
        // Check balances
        assertEq(token.totalSupply(), shares - sharesRedeemed);
        assertEq(token.balanceOf(alice), shares - sharesRedeemed);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - INITIAL_DEPOSIT + withdrawAmount);
        
        // Check asset accounting - strategy decreases balance itself
        assertEq(token.totalAssets(), INITIAL_DEPOSIT - withdrawAmount);
    }
    
    function test_Withdraw_WithCallback() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Then withdraw with callback
        uint256 withdrawAmount = INITIAL_DEPOSIT / 2;
        
        // Update strategy balance (deposit increased it)
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT); 
        
        vm.startPrank(address(callbackReceiver));
        uint256 sharesRedeemed = token.withdraw(
            withdrawAmount,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        vm.stopPrank();
        
        // Check callback was received
        assertTrue(callbackReceiver.callbackReceived());
        assertEq(callbackReceiver.lastOperationType(), keccak256("WITHDRAW"));
        assertTrue(callbackReceiver.lastSuccess());
        
        // Check balances
        assertEq(token.balanceOf(address(callbackReceiver)), shares - sharesRedeemed);
        assertEq(usdc.balanceOf(address(callbackReceiver)), withdrawAmount);
    }
    
    function test_Redeem() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Then redeem half the shares
        uint256 sharesToRedeem = shares / 2;
        
        // Update strategy balance so it can handle withdrawal
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        vm.startPrank(alice);
        uint256 assetsReceived = token.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();
        
        // Check balances
        assertEq(token.balanceOf(alice), shares - sharesToRedeem);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - INITIAL_DEPOSIT + assetsReceived);
        
        // Check that assets received are approximately half of deposited assets
        assertApproxEqRel(assetsReceived, INITIAL_DEPOSIT / 2, 1e16); // 1% tolerance
        
        // Check asset accounting - strategy withdrawal changes balance
        assertEq(token.totalAssets(), INITIAL_DEPOSIT - assetsReceived);
    }
    
    function test_Redeem_WithCallback() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Update strategy balance again for redemption
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // Then redeem with callback
        vm.startPrank(address(callbackReceiver));
        uint256 sharesToRedeem = shares / 2;
        uint256 assetsReceived = token.redeem(
            sharesToRedeem,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        vm.stopPrank();
        
        // Check callback was received
        assertTrue(callbackReceiver.callbackReceived());
        assertEq(callbackReceiver.lastOperationType(), keccak256("REDEEM"));
        assertTrue(callbackReceiver.lastSuccess());
        
        // Check balances
        assertEq(token.balanceOf(address(callbackReceiver)), shares - sharesToRedeem);
        assertEq(usdc.balanceOf(address(callbackReceiver)), assetsReceived);
    }
    
    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL TESTS (QUEUED)
    //////////////////////////////////////////////////////////////*/
    
    function test_Withdraw_Queued() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Configure rules to queue withdrawals instead of processing them directly
        queueRules.setWithdrawalsQueued(true);
        
        // Set up strategy 
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // Try to withdraw via redeem - it will be queued (avoids share balance check)
        vm.startPrank(alice);
        uint256 sharesToRedeem = shares / 2;
        
        // Calculate expected assets
        uint256 expectedAssets = token.previewRedeem(sharesToRedeem);
        
        vm.expectEmit(true, false, false, true);
        emit tRWA.WithdrawalQueued(alice, expectedAssets, sharesToRedeem);
        
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Direct withdrawals not supported. Withdrawal request created in queue."));
        token.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();
        
        // Check that funds are still in token
        assertEq(token.balanceOf(alice), shares);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - INITIAL_DEPOSIT);
    }
    
    function test_Withdraw_Queued_WithCallback() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Configure rules to queue withdrawals instead of processing them directly
        queueRules.setWithdrawalsQueued(true);
        
        // Try to withdraw with callback - it will be queued but callback still fires
        vm.startPrank(address(callbackReceiver));
        uint256 withdrawAmount = INITIAL_DEPOSIT / 2;
        
        // Calculate expected shares
        uint256 expectedShares = token.previewWithdraw(withdrawAmount);
        
        // This should emit the queued event but ultimately revert
        vm.expectEmit(true, false, false, true);
        emit tRWA.WithdrawalQueued(address(callbackReceiver), withdrawAmount, expectedShares);
        
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Direct withdrawals not supported. Withdrawal request created in queue."));
        token.withdraw(
            withdrawAmount,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        vm.stopPrank();
        
        // Check that tokens never left
        assertEq(token.balanceOf(address(callbackReceiver)), shares);
    }
    
    function test_Redeem_Queued() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Configure rules to queue withdrawals instead of processing them directly
        queueRules.setWithdrawalsQueued(true);
        
        // Calculate expected assets
        uint256 sharesToRedeem = shares / 2;
        uint256 expectedAssets = token.previewRedeem(sharesToRedeem);
        
        // Try to redeem - it will be queued
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, true);
        emit tRWA.WithdrawalQueued(alice, expectedAssets, sharesToRedeem);
        
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Direct withdrawals not supported. Withdrawal request created in queue."));
        token.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();
        
        // Check that funds are still in token
        assertEq(token.totalSupply(), shares);
        assertEq(token.balanceOf(alice), shares);
        assertEq(usdc.balanceOf(alice), 10_000 * 10**6 - INITIAL_DEPOSIT);
    }
    
    function test_Redeem_Queued_WithCallback() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 shares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Configure rules to queue withdrawals instead of processing them directly
        queueRules.setWithdrawalsQueued(true);
        
        // Calculate expected assets
        uint256 sharesToRedeem = shares / 2;
        uint256 expectedAssets = token.previewRedeem(sharesToRedeem);
        
        // Try to redeem with callback - it will be queued but callback still fires
        vm.startPrank(address(callbackReceiver));
        
        // This should emit the queued event but ultimately revert
        vm.expectEmit(true, false, false, true);
        emit tRWA.WithdrawalQueued(address(callbackReceiver), expectedAssets, sharesToRedeem);
        
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Direct withdrawals not supported. Withdrawal request created in queue."));
        token.redeem(
            sharesToRedeem,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        vm.stopPrank();
        
        // Check that tokens never left
        assertEq(token.balanceOf(address(callbackReceiver)), shares);
    }
    
    /*//////////////////////////////////////////////////////////////
                    WITHDRAWAL TESTS (OTHER ERRORS)
    //////////////////////////////////////////////////////////////*/
    
    function test_Withdraw_FailsWithOtherError() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 callbackShares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Configure rules to reject withdrawals with non-queue error
        queueRules.setApproveStatus(false, "Test rejection");
        
        // Try withdraw with callback
        vm.startPrank(address(callbackReceiver));
        
        // Directly try redeem instead of withdraw as it doesn't check share balance first
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Test rejection"));
        token.redeem(
            callbackShares / 2,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        
        vm.stopPrank();
        
        // Check balances unchanged
        assertEq(token.balanceOf(address(callbackReceiver)), callbackShares);
    }
    
    function test_Redeem_FailsWithOtherError() public {
        // Mint tokens to callback receiver
        usdc.mint(address(callbackReceiver), INITIAL_DEPOSIT);
        
        // Setup strategy for deposit
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // First deposit from callback receiver
        vm.startPrank(address(callbackReceiver));
        usdc.approve(address(token), INITIAL_DEPOSIT);
        uint256 callbackShares = token.deposit(INITIAL_DEPOSIT, address(callbackReceiver), false, "");
        vm.stopPrank();
        
        // Reset callback state
        callbackReceiver.resetState();
        
        // Configure rules to reject withdrawals with non-queue error
        queueRules.setApproveStatus(false, "Test rejection");
        
        // Setup strategy for redemption (even though it will fail)
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // Try to redeem with callback
        vm.startPrank(address(callbackReceiver));
        
        // Try to redeem
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Test rejection"));
        token.redeem(
            callbackShares / 2,
            address(callbackReceiver),
            address(callbackReceiver),
            true,
            ""
        );
        
        vm.stopPrank();
        
        // Check balances unchanged
        assertEq(token.balanceOf(address(callbackReceiver)), callbackShares);
    }
    
    /*//////////////////////////////////////////////////////////////
                            BURN TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Burn() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Let's say strategy wants to burn tokens
        vm.prank(address(strategy));
        token.burn(alice, shares / 2);
        
        // Check balances
        assertEq(token.totalSupply(), shares / 2);
        assertEq(token.balanceOf(alice), shares / 2);
    }
    
    function test_Burn_FailsWhenRulesReject() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Set rules to reject
        queueRules.setApproveStatus(false, "Test rejection");
        
        // Try to burn
        vm.prank(address(strategy));
        vm.expectRevert(abi.encodeWithSignature("RuleCheckFailed(string)", "Test rejection"));
        token.burn(alice, shares / 2);
    }
    
    /*//////////////////////////////////////////////////////////////
                    WITHDRAW ALLOWANCE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_WithdrawByApproval() public {
        // First deposit from alice
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Alice approves bob to spend her tokens
        vm.prank(alice);
        token.approve(bob, shares);
        
        // Setup strategy for withdrawal
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT);
        
        // Bob withdraws on behalf of alice
        vm.prank(bob);
        uint256 sharesRedeemed = token.withdraw(INITIAL_DEPOSIT / 2, bob, alice);
        
        // Check balances
        assertEq(token.totalSupply(), shares - sharesRedeemed);
        assertEq(token.balanceOf(alice), shares - sharesRedeemed);
        assertEq(usdc.balanceOf(bob), 10_000 * 10**6 + INITIAL_DEPOSIT / 2);
    }
    
    function test_Withdraw_ExceedsBalance() public {
        // First deposit
        uint256 shares = depositTRWA(alice, address(token), INITIAL_DEPOSIT);
        
        // Setup strategy for withdrawal (even though it will fail)
        vm.prank(owner);
        strategy.setBalance(INITIAL_DEPOSIT * 2); // Let strategy allow the withdrawal
        
        // Try to withdraw more than balance
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("WithdrawMoreThanMax()"));
        token.withdraw(INITIAL_DEPOSIT * 2, alice, alice);
    }
}