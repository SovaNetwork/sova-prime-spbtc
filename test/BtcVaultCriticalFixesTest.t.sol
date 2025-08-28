// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title BtcVaultCriticalFixesTest
 * @notice Test suite for critical bug fixes:
 * 1. NAV-aware minting (not 1:1 fixed ratio)
 * 2. availableLiquidity tracking and defensive accounting
 * @dev Tests ensure both bugs identified during audit are properly fixed
 */
contract BtcVaultCriticalFixesTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public vaultToken;
    PriceOracleReporter public reporter;
    RoleManager public roleManager;

    MockERC20 public wbtc;
    MockERC20 public tbtc;
    MockERC20 public sovaBTC;

    address public manager = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public attacker = address(0x4);

    function setUp() public {
        // Deploy mock tokens
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        tbtc = new MockERC20("tBTC", "tBTC", 8);
        sovaBTC = new MockERC20("sovaBTC", "SOVABTC", 8);

        // Deploy role manager
        roleManager = new RoleManager();
        roleManager.grantRole(manager, roleManager.STRATEGY_ADMIN());

        // Deploy reporter with initial price of 1:1
        reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            manager, // Updater  
            10000, // Max deviation (100% - for testing instant changes)
            1 // Time period (1 second - for testing)
        );

        // Deploy strategy
        strategy = new BtcVaultStrategy();
        bytes memory initData = abi.encode(address(reporter));
        strategy.initialize(
            "BTC Vault Strategy", "BTC-STRAT", address(roleManager), manager, address(sovaBTC), 8, initData
        );

        // Get deployed vault token
        vaultToken = BtcVaultToken(strategy.sToken());

        // Add supported collaterals
        vm.startPrank(manager);
        strategy.addCollateral(address(wbtc));
        strategy.addCollateral(address(tbtc));
        vm.stopPrank();

        // Mint tokens for testing
        wbtc.mint(alice, 100e8);
        tbtc.mint(alice, 100e8);
        sovaBTC.mint(alice, 100e8);
        
        wbtc.mint(bob, 100e8);
        tbtc.mint(bob, 100e8);
        sovaBTC.mint(bob, 100e8);
        
        wbtc.mint(attacker, 100e8);
        sovaBTC.mint(attacker, 100e8);
    }

    /*//////////////////////////////////////////////////////////////
                    BUG #1: NAV-AWARE MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test that minting respects NAV when price per share is 1:1
     */
    function test_NAVAwareMinting_AtPar() public {
        uint256 depositAmount = 1e8; // 1 BTC
        
        // Alice deposits first at 1:1 NAV
        vm.startPrank(alice);
        wbtc.approve(address(vaultToken), depositAmount);
        
        uint256 sharesBefore = vaultToken.balanceOf(alice);
        uint256 shares = vaultToken.depositCollateral(address(wbtc), depositAmount, alice);
        uint256 sharesAfter = vaultToken.balanceOf(alice);
        
        // At 1:1 NAV, 1 BTC (1e8) should mint 1e18 shares
        assertEq(shares, 1e18, "Should receive 1e18 shares at 1:1 NAV");
        assertEq(sharesAfter - sharesBefore, shares, "Share balance should increase correctly");
        vm.stopPrank();
    }

    /**
     * @notice CRITICAL TEST: Minting must respect NAV when price per share > 1
     * This test would fail with the old bug (fixed 1:1 minting)
     */
    function test_NAVAwareMinting_AbovePar() public {
        uint256 firstDeposit = 1e8; // 1 BTC
        uint256 secondDeposit = 1e8; // 1 BTC
        
        // Alice deposits first at 1:1 NAV
        vm.startPrank(alice);
        wbtc.approve(address(vaultToken), firstDeposit);
        uint256 aliceShares = vaultToken.depositCollateral(address(wbtc), firstDeposit, alice);
        assertEq(aliceShares, 1e18, "Alice should receive 1e18 shares at 1:1 NAV");
        vm.stopPrank();
        
        // Simulate vault appreciation: update price per share to 2.0
        vm.startPrank(manager);
        reporter.update(2e18, "test"); // 2.0 price per share
        // Force immediate transition for testing
        vm.warp(block.timestamp + 2);
        vm.stopPrank();
        
        // Bob deposits after NAV increased to 2.0
        vm.startPrank(bob);
        wbtc.approve(address(vaultToken), secondDeposit);
        
        // Preview should show correct shares based on NAV
        uint256 expectedShares = vaultToken.previewDepositCollateral(address(wbtc), secondDeposit);
        uint256 bobShares = vaultToken.depositCollateral(address(wbtc), secondDeposit, bob);
        
        // At 2:1 NAV, 1 BTC should mint ~0.5e18 shares (not 1e18!)  
        // Allow small rounding difference
        assertApproxEqAbs(bobShares, 0.5e18, 1e10, "Bob should receive ~0.5e18 shares at 2:1 NAV");
        assertEq(bobShares, expectedShares, "Actual shares should match preview");
        
        // Verify no dilution occurred
        // Alice still owns 2/3 of the vault (1e18 / 1.5e18 total shares)
        uint256 totalShares = vaultToken.totalSupply();
        // Allow for small rounding differences
        assertApproxEqAbs(totalShares, 1.5e18, 1e10, "Total shares should be ~1.5e18");
        
        // Alice's share value should still be ~2 BTC (minus rounding)
        uint256 aliceAssetValue = vaultToken.convertToAssets(aliceShares);
        assertApproxEqRelCustom(aliceAssetValue, 2e8, 0.01e18, "Alice's shares should be worth ~2 BTC");
        
        vm.stopPrank();
    }

    /**
     * @notice Test minting when NAV is below par (loss scenario)
     */
    function test_NAVAwareMinting_BelowPar() public {
        uint256 firstDeposit = 1e8; // 1 BTC
        uint256 secondDeposit = 1e8; // 1 BTC
        
        // Alice deposits first at 1:1 NAV
        vm.startPrank(alice);
        wbtc.approve(address(vaultToken), firstDeposit);
        uint256 aliceShares = vaultToken.depositCollateral(address(wbtc), firstDeposit, alice);
        vm.stopPrank();
        
        // Simulate vault loss: update price per share to 0.5
        vm.startPrank(manager);
        reporter.update(0.5e18, "test"); // 0.5 price per share
        // Force immediate transition for testing
        vm.warp(block.timestamp + 2);
        vm.stopPrank();
        
        // Bob deposits after NAV decreased to 0.5
        vm.startPrank(bob);
        wbtc.approve(address(vaultToken), secondDeposit);
        uint256 bobShares = vaultToken.depositCollateral(address(wbtc), secondDeposit, bob);
        
        // At 0.5:1 NAV, 1 BTC should mint ~2e18 shares
        // Allow small rounding difference (price transitions can cause minor variations)
        assertApproxEqAbs(bobShares, 2e18, 1e11, "Bob should receive ~2e18 shares at 0.5:1 NAV");
        
        // Total shares should be ~3e18 (1 + 2)
        assertApproxEqAbs(vaultToken.totalSupply(), 3e18, 1e11, "Total shares should be ~3e18");
        vm.stopPrank();
    }

    /**
     * @notice Test that preview function correctly calculates shares based on NAV
     */
    function test_PreviewDepositCollateral_RespectsNAV() public {
        uint256 amount = 1e8; // 1 BTC
        
        // Test at 1:1 NAV
        uint256 sharesAt1x = vaultToken.previewDepositCollateral(address(wbtc), amount);
        assertEq(sharesAt1x, 1e18, "Should preview 1e18 shares at 1:1 NAV");
        
        // Update NAV to 1.5x
        vm.startPrank(manager);
        reporter.update(1.5e18, "test");
        vm.warp(block.timestamp + 2);
        vm.stopPrank();
        
        // Need to make a deposit first so totalSupply > 0 for proper NAV calculation
        vm.startPrank(alice);
        wbtc.approve(address(vaultToken), 1e8);
        vaultToken.depositCollateral(address(wbtc), 1e8, alice);
        vm.stopPrank();
        
        // Now test preview at 1.5x NAV
        uint256 sharesAt1_5x = vaultToken.previewDepositCollateral(address(wbtc), amount);
        // At 1.5x NAV with supply, should get proportionally fewer shares
        assertLt(sharesAt1_5x, sharesAt1x, "Should preview fewer shares at higher NAV");
    }

    /*//////////////////////////////////////////////////////////////
            BUG #2: AVAILABLE LIQUIDITY TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test that sovaBTC deposits update availableLiquidity
     */
    function test_AvailableLiquidity_UpdatesOnSovaBTCDeposit() public {
        uint256 depositAmount = 10e8; // 10 BTC
        
        // Check initial liquidity
        uint256 initialLiquidity = strategy.availableLiquidity();
        assertEq(initialLiquidity, 0, "Initial liquidity should be 0");
        
        // Alice deposits sovaBTC
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        // Check liquidity increased
        uint256 newLiquidity = strategy.availableLiquidity();
        assertEq(newLiquidity, depositAmount, "Liquidity should increase by deposit amount");
    }

    /**
     * @notice Test that non-sovaBTC deposits don't affect availableLiquidity
     */
    function test_AvailableLiquidity_NoUpdateOnWBTCDeposit() public {
        uint256 depositAmount = 10e8; // 10 BTC
        
        // Check initial liquidity
        uint256 initialLiquidity = strategy.availableLiquidity();
        
        // Alice deposits WBTC (not sovaBTC)
        vm.startPrank(alice);
        wbtc.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(wbtc), depositAmount, alice);
        vm.stopPrank();
        
        // Check liquidity unchanged
        uint256 newLiquidity = strategy.availableLiquidity();
        assertEq(newLiquidity, initialLiquidity, "Liquidity should not change for WBTC deposits");
    }

    /**
     * @notice Test defensive clamping when direct transfer inflates balance
     */
    function test_DefensiveClamping_DirectTransfer() public {
        uint256 depositAmount = 10e8; // 10 BTC
        uint256 directTransfer = 5e8; // 5 BTC
        
        // Alice deposits normally
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        // Someone sends sovaBTC directly to strategy (bypassing deposit)
        vm.prank(attacker);
        sovaBTC.transfer(address(strategy), directTransfer);
        
        // Bob deposits after direct transfer
        vm.startPrank(bob);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, bob);
        vm.stopPrank();
        
        // Available liquidity should be clamped to actual balance
        uint256 actualBalance = sovaBTC.balanceOf(address(strategy));
        uint256 availableLiq = strategy.availableLiquidity();
        
        assertEq(actualBalance, depositAmount + directTransfer + depositAmount, "Actual balance check");
        assertLe(availableLiq, actualBalance, "Available liquidity should not exceed actual balance");
    }

    /**
     * @notice Test that withdrawCollateral properly decrements availableLiquidity
     */
    function test_WithdrawCollateral_DecrementsLiquidity() public {
        uint256 depositAmount = 10e8; // 10 BTC
        uint256 withdrawAmount = 3e8; // 3 BTC
        
        // Setup: deposit sovaBTC
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        uint256 liquidityBefore = strategy.availableLiquidity();
        assertEq(liquidityBefore, depositAmount, "Liquidity should equal deposit");
        
        // Manager withdraws some sovaBTC
        vm.prank(manager);
        strategy.withdrawCollateral(address(sovaBTC), withdrawAmount, manager);
        
        uint256 liquidityAfter = strategy.availableLiquidity();
        assertEq(liquidityAfter, depositAmount - withdrawAmount, "Liquidity should decrease by withdrawal");
    }

    /**
     * @notice Test that withdrawing more than availableLiquidity reverts
     */
    function test_WithdrawCollateral_RevertsOnExcessWithdrawal() public {
        uint256 depositAmount = 10e8; // 10 BTC
        
        // Setup: deposit sovaBTC
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        // Try to withdraw more than available liquidity
        vm.prank(manager);
        vm.expectRevert(); // Should revert with InsufficientLiquidity
        strategy.withdrawCollateral(address(sovaBTC), depositAmount + 1, manager);
    }

    /**
     * @notice Test that liquidity is now direct balance check
     */
    function test_LiquidityIsDirectBalance() public {
        uint256 depositAmount = 10e8; // 10 BTC
        
        // Setup: deposit sovaBTC to establish liquidity
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        // Liquidity should equal actual balance
        assertEq(strategy.availableLiquidity(), sovaBTC.balanceOf(address(strategy)), "Liquidity should match balance");
        
        // Simulate a direct transfer (not through addLiquidity)
        vm.prank(attacker);
        sovaBTC.transfer(address(strategy), 5e8);
        
        // Liquidity should automatically reflect new balance
        assertEq(strategy.availableLiquidity(), 15e8, "Liquidity should automatically update");
        assertEq(sovaBTC.balanceOf(address(strategy)), 15e8, "Balance check");
    }

    /**
     * @notice Test defensive accounting - withdrawals respect actual balance
     */
    function test_DefensiveAccounting_RespectsBalance() public {
        uint256 depositAmount = 5e8; // 5 BTC
        
        // Setup: deposit sovaBTC
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        vaultToken.depositCollateral(address(sovaBTC), depositAmount, alice);
        vm.stopPrank();
        
        // Manager tries to withdraw more than actual balance
        vm.startPrank(manager);
        
        // Should revert - can't withdraw more than balance
        vm.expectRevert();
        strategy.withdrawCollateral(address(sovaBTC), 20e8, alice);
        
        // Withdraw within balance should work
        strategy.withdrawCollateral(address(sovaBTC), 3e8, alice);
        assertEq(sovaBTC.balanceOf(alice), 98e8, "Alice should receive withdrawn amount");
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    INTEGRATION & EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test multiple deposits with NAV changes and liquidity tracking
     */
    function test_Integration_MultipleDepositsWithNAVChanges() public {
        // First deposit at 1:1 NAV
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), 10e8);
        uint256 aliceShares = vaultToken.depositCollateral(address(sovaBTC), 10e8, alice);
        vm.stopPrank();
        
        assertEq(aliceShares, 10e18, "Alice gets 10e18 shares at 1:1");
        assertEq(strategy.availableLiquidity(), 10e8, "Liquidity is 10e8");
        
        // NAV increases to 1.5x
        vm.startPrank(manager);
        reporter.update(1.5e18, "test");
        vm.warp(block.timestamp + 2);
        vm.stopPrank();
        
        // Bob deposits WBTC (no liquidity impact)
        vm.startPrank(bob);
        wbtc.approve(address(vaultToken), 6e8);
        uint256 bobShares = vaultToken.depositCollateral(address(wbtc), 6e8, bob);
        vm.stopPrank();
        
        // Allow small rounding difference
        assertApproxEqAbs(bobShares, 4e18, 1e10, "Bob gets ~4e18 shares at 1.5x NAV");
        assertEq(strategy.availableLiquidity(), 10e8, "Liquidity unchanged from WBTC");
        
        // Attacker deposits sovaBTC
        vm.startPrank(attacker);
        sovaBTC.approve(address(vaultToken), 15e8);
        uint256 attackerShares = vaultToken.depositCollateral(address(sovaBTC), 15e8, attacker);
        vm.stopPrank();
        
        // Allow small rounding difference
        assertApproxEqAbs(attackerShares, 10e18, 1e10, "Attacker gets ~10e18 shares at 1.5x NAV");
        assertEq(strategy.availableLiquidity(), 25e8, "Liquidity increased to 25e8");
        
        // Verify total supply and proportions
        uint256 totalShares = vaultToken.totalSupply();
        assertApproxEqAbs(totalShares, 24e18, 1e11, "Total shares: ~10 + 4 + 10 = 24");
    }

    /**
     * @notice Test that duplicate notifications are handled safely
     */
    function test_DefensiveAccounting_DuplicateNotification() public {
        uint256 depositAmount = 10e8;
        
        // Alice deposits sovaBTC
        vm.startPrank(alice);
        sovaBTC.approve(address(vaultToken), depositAmount);
        
        // Transfer happens
        sovaBTC.transfer(address(strategy), depositAmount);
        
        // Call notifyCollateralDeposit directly (simulating duplicate notification)
        vm.stopPrank();
        vm.prank(address(vaultToken));
        strategy.notifyCollateralDeposit(address(sovaBTC), depositAmount);
        
        // Available liquidity should equal actual balance (clamped)
        assertEq(strategy.availableLiquidity(), depositAmount, "Liquidity clamped to actual balance");
        
        // Try duplicate notification
        vm.prank(address(vaultToken));
        strategy.notifyCollateralDeposit(address(sovaBTC), depositAmount);
        
        // Still should be clamped to actual balance
        assertEq(strategy.availableLiquidity(), depositAmount, "Liquidity still clamped correctly");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function assertApproxEqRelCustom(uint256 actual, uint256 expected, uint256 tolerance, string memory err) internal {
        uint256 diff = actual > expected ? actual - expected : expected - actual;
        uint256 maxDiff = (expected * tolerance) / 1e18;
        assertLe(diff, maxDiff, err);
    }
}