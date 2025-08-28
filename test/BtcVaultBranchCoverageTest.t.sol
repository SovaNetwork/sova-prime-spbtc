// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../src/token/BtcVaultToken.sol";
import {IBtcVaultStrategy} from "../src/interfaces/IBtcVaultStrategy.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title BtcVaultBranchCoverageTest
 * @notice Additional tests to improve branch coverage for BTC vault contracts
 * @dev Focuses on edge cases and specific branch conditions
 */
contract BtcVaultBranchCoverageTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public vaultToken;
    PriceOracleReporter public reporter;
    RoleManager public roleManager;

    MockERC20 public wbtc;
    MockERC20 public sovaBTC;
    MockERC20 public unsupportedToken;

    address public manager = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        // Deploy mock tokens
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        sovaBTC = new MockERC20("sovaBTC", "SOVABTC", 8);
        unsupportedToken = new MockERC20("Unsupported", "UNSUP", 8);

        // Deploy role manager
        roleManager = new RoleManager();
        roleManager.grantRole(manager, roleManager.STRATEGY_ADMIN());

        // Deploy reporter
        reporter = new PriceOracleReporter(1e18, manager, 100, 86400);

        // Deploy strategy
        strategy = new BtcVaultStrategy();
        bytes memory initData = abi.encode(address(reporter));
        strategy.initialize(
            "BTC Vault Strategy", "BTC-STRAT", address(roleManager), manager, address(sovaBTC), 8, initData
        );

        // Get deployed vault token
        vaultToken = BtcVaultToken(strategy.sToken());

        // Add supported collateral
        vm.prank(manager);
        strategy.addCollateral(address(wbtc), 8);

        // Mint tokens
        wbtc.mint(user, 100e8);
        sovaBTC.mint(user, 100e8);
        sovaBTC.mint(manager, 100e8); // Manager needs tokens for liquidity operations
        unsupportedToken.mint(user, 100e8);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSITCOLLATERAL BRANCH COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_DepositCollateral_UnsupportedToken() public {
        vm.startPrank(user);
        unsupportedToken.approve(address(strategy), 1e8);

        vm.expectRevert(IBtcVaultStrategy.AssetNotSupported.selector);
        strategy.depositCollateral(address(unsupportedToken), 1e8);
        vm.stopPrank();
    }

    function test_DepositCollateral_ZeroAmount() public {
        vm.startPrank(user);
        wbtc.approve(address(strategy), 1e8);

        vm.expectRevert(IBtcVaultStrategy.InvalidAmount.selector);
        strategy.depositCollateral(address(wbtc), 0);
        vm.stopPrank();
    }

    function test_DepositCollateral_NonSovaBTC() public {
        // Test depositing a supported collateral that is NOT sovaBTC
        // This tests the branch where token != asset
        vm.startPrank(user);
        wbtc.approve(address(strategy), 1e8);

        uint256 liquidityBefore = strategy.availableLiquidity();
        strategy.depositCollateral(address(wbtc), 1e8);
        uint256 liquidityAfter = strategy.availableLiquidity();

        // Liquidity should NOT increase for non-sovaBTC deposits
        assertEq(liquidityBefore, liquidityAfter);
        assertEq(wbtc.balanceOf(address(strategy)), 1e8);
        vm.stopPrank();
    }

    function test_DepositCollateral_SovaBTC() public {
        // Test depositing sovaBTC directly
        // This tests the branch where token == asset
        vm.startPrank(user);
        sovaBTC.approve(address(strategy), 1e8);

        uint256 liquidityBefore = strategy.availableLiquidity();
        strategy.depositCollateral(address(sovaBTC), 1e8);
        uint256 liquidityAfter = strategy.availableLiquidity();

        // Liquidity SHOULD increase for sovaBTC deposits
        assertEq(liquidityAfter - liquidityBefore, 1e8);
        assertEq(sovaBTC.balanceOf(address(strategy)), 1e8);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAWCOLLATERAL BRANCH COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawCollateral_NotSovaBTC() public {
        // First deposit some WBTC
        vm.startPrank(user);
        wbtc.approve(address(strategy), 5e8);
        strategy.depositCollateral(address(wbtc), 5e8);
        vm.stopPrank();

        // Withdraw WBTC (not sovaBTC) - tests branch where token != asset
        vm.startPrank(manager);
        uint256 liquidityBefore = strategy.availableLiquidity();
        strategy.withdrawCollateral(address(wbtc), 2e8, user);
        uint256 liquidityAfter = strategy.availableLiquidity();

        // Liquidity should NOT change
        assertEq(liquidityBefore, liquidityAfter);
        assertEq(wbtc.balanceOf(user), 100e8 - 5e8 + 2e8); // original - deposited + withdrawn
        vm.stopPrank();
    }

    function test_WithdrawCollateral_SovaBTC_ExceedsLiquidity() public {
        // Add some sovaBTC to strategy
        vm.startPrank(manager);
        sovaBTC.mint(address(strategy), 10e8);
        // Don't update availableLiquidity, so balance > liquidity
        vm.stopPrank();

        // Try to withdraw more than availableLiquidity but less than balance
        // This should now REVERT due to the critical fix for proper liquidity tracking
        vm.startPrank(manager);
        uint256 liquidityBefore = strategy.availableLiquidity();
        assertEq(liquidityBefore, 0); // No liquidity tracked

        // CRITICAL FIX: This now correctly reverts when trying to withdraw more than tracked liquidity
        vm.expectRevert(BtcVaultStrategy.InsufficientLiquidity.selector);
        strategy.withdrawCollateral(address(sovaBTC), 5e8, user);
        
        // Liquidity remains unchanged since withdrawal was reverted
        uint256 liquidityAfter = strategy.availableLiquidity();
        assertEq(liquidityAfter, 0);
        vm.stopPrank();
    }

    function test_WithdrawCollateral_SovaBTC_WithinLiquidity() public {
        // Add liquidity properly
        vm.startPrank(manager);
        sovaBTC.approve(address(strategy), 10e8);
        strategy.addLiquidity(10e8);

        uint256 liquidityBefore = strategy.availableLiquidity();
        assertEq(liquidityBefore, 10e8);

        // Withdraw within available liquidity
        // This tests the branch where token == asset && amount <= availableLiquidity
        strategy.withdrawCollateral(address(sovaBTC), 3e8, user);

        uint256 liquidityAfter = strategy.availableLiquidity();
        assertEq(liquidityAfter, 7e8); // Properly decremented
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    VAULT TOKEN ZERO SHARES BRANCH
    //////////////////////////////////////////////////////////////*/

    function test_DepositCollateral_MinimumAmount() public {
        // Test depositing exactly the minimum amount
        uint256 minDeposit = vaultToken.MIN_DEPOSIT(); // 1e5 (0.001 BTC)

        vm.startPrank(user);
        wbtc.approve(address(vaultToken), minDeposit);

        uint256 shares = vaultToken.depositCollateral(address(wbtc), minDeposit, user);
        assertEq(shares, minDeposit * 10 ** 10);
        assertEq(vaultToken.balanceOf(user), shares);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                REMOVECOLLATERAL ARRAY MANIPULATION BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_RemoveCollateral_LastInArray() public {
        // Add multiple collaterals
        MockERC20 token1 = new MockERC20("Token1", "TK1", 8);
        MockERC20 token2 = new MockERC20("Token2", "TK2", 8);

        vm.startPrank(manager);
        strategy.addCollateral(address(token1), 8);
        strategy.addCollateral(address(token2), 8);

        // Remove the last one (token2)
        // This tests a different branch in the array removal logic
        strategy.removeCollateral(address(token2));

        address[] memory collaterals = strategy.getSupportedCollaterals();

        // Verify token2 is removed and array is correct
        bool foundToken2 = false;
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i] == address(token2)) {
                foundToken2 = true;
                break;
            }
        }
        assertFalse(foundToken2);
        assertTrue(strategy.isSupportedAsset(address(token1)));
        assertFalse(strategy.isSupportedAsset(address(token2)));
        vm.stopPrank();
    }

    function test_RemoveCollateral_FirstInArray() public {
        // Add multiple collaterals
        MockERC20 token1 = new MockERC20("Token1", "TK1", 8);
        MockERC20 token2 = new MockERC20("Token2", "TK2", 8);
        MockERC20 token3 = new MockERC20("Token3", "TK3", 8);

        vm.startPrank(manager);
        strategy.addCollateral(address(token1), 8);
        strategy.addCollateral(address(token2), 8);
        strategy.addCollateral(address(token3), 8);

        // Get initial array order
        address[] memory collateralsBefore = strategy.getSupportedCollaterals();
        uint256 lengthBefore = collateralsBefore.length;

        // Remove the first added token (after sovaBTC and wbtc)
        // This will test the array swap and pop logic
        strategy.removeCollateral(address(token1));

        address[] memory collateralsAfter = strategy.getSupportedCollaterals();
        assertEq(collateralsAfter.length, lengthBefore - 1);

        // Verify token1 is removed
        assertFalse(strategy.isSupportedAsset(address(token1)));
        assertTrue(strategy.isSupportedAsset(address(token2)));
        assertTrue(strategy.isSupportedAsset(address(token3)));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    COLLATERAL BALANCES TEST
    //////////////////////////////////////////////////////////////*/

    function test_CollateralBalance() public {
        // Deposit some collateral and check balance
        vm.startPrank(user);
        wbtc.approve(address(strategy), 3e8);
        strategy.depositCollateral(address(wbtc), 3e8);
        vm.stopPrank();

        uint256 balance = strategy.collateralBalance(address(wbtc));
        assertEq(balance, 3e8);
    }

    function test_CollateralBalance_Zero() public view {
        // Check balance of token with no deposits
        uint256 balance = strategy.collateralBalance(address(wbtc));
        assertEq(balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    TOTAL ASSETS CALCULATION BRANCHES
    //////////////////////////////////////////////////////////////*/

    function test_TotalAssets_MixedCollaterals() public {
        // Deposit various collaterals to test totalAssets calculation
        vm.startPrank(user);

        // Deposit WBTC
        wbtc.approve(address(strategy), 2e8);
        strategy.depositCollateral(address(wbtc), 2e8);

        // Deposit sovaBTC
        sovaBTC.approve(address(strategy), 3e8);
        strategy.depositCollateral(address(sovaBTC), 3e8);

        vm.stopPrank();

        // Total assets should be sum of all collaterals (all 1:1 with sovaBTC)
        uint256 totalAssets = strategy.totalCollateralAssets();
        assertEq(totalAssets, 5e8); // 2 WBTC + 3 sovaBTC
    }

    function test_TotalAssets_EmptyStrategy() public {
        // Test totalCollateralAssets when strategy has no deposits
        uint256 totalAssets = strategy.totalCollateralAssets();
        assertEq(totalAssets, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    LIQUIDITY EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_RemoveLiquidity_MoreThanAvailable() public {
        // Add some liquidity
        vm.startPrank(manager);
        sovaBTC.approve(address(strategy), 5e8);
        strategy.addLiquidity(5e8);

        // Try to remove more than available
        vm.expectRevert(IBtcVaultStrategy.InsufficientLiquidity.selector);
        strategy.removeLiquidity(10e8, user);
        vm.stopPrank();
    }

    function test_RemoveLiquidity_ExactAmount() public {
        // Add liquidity and remove exact amount
        vm.startPrank(manager);
        sovaBTC.approve(address(strategy), 5e8);
        strategy.addLiquidity(5e8);

        assertEq(strategy.availableLiquidity(), 5e8);

        // Remove exactly what's available
        strategy.removeLiquidity(5e8, user);

        assertEq(strategy.availableLiquidity(), 0);
        assertEq(sovaBTC.balanceOf(user), 100e8 + 5e8); // original + removed
        vm.stopPrank();
    }
}
