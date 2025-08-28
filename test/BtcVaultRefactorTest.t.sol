// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../src/token/BtcVaultToken.sol";
import {ManagedWithdrawRWA} from "../src/token/ManagedWithdrawRWA.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {Registry} from "../src/registry/Registry.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title BtcVaultRefactorTest
 * @notice Tests for the refactored BTC vault using ManagedWithdrawRWAStrategy pattern
 */
contract BtcVaultRefactorTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public vaultToken;
    PriceOracleReporter public reporter;
    RoleManager public roleManager;
    Registry public registry;

    MockERC20 public sovaBTC;
    MockERC20 public wBTC;
    MockERC20 public tBTC;

    address public owner = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy infrastructure
        roleManager = new RoleManager();
        registry = new Registry(address(roleManager));

        // Deploy mock tokens (8 decimals for BTC tokens)
        sovaBTC = new MockERC20("Sova BTC", "sovaBTC", 8);
        wBTC = new MockERC20("Wrapped BTC", "WBTC", 8);
        tBTC = new MockERC20("Threshold BTC", "tBTC", 8);

        // Deploy reporter with initial price
        reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            owner, // Updater
            100, // Max deviation (1%)
            86400 // Time period (24 hours)
        );

        // Deploy and initialize strategy
        strategy = new BtcVaultStrategy();
        bytes memory initData = abi.encode(address(reporter));
        strategy.initialize(
            "BTC Vault Strategy", "BTC-STRAT", address(roleManager), manager, address(sovaBTC), 8, initData
        );

        // The strategy automatically deploys BtcVaultToken during initialization
        vaultToken = BtcVaultToken(strategy.sToken());

        // Setup roles
        roleManager.grantRole(manager, roleManager.STRATEGY_ADMIN());

        vm.stopPrank();

        // Configure strategy as manager
        vm.startPrank(manager);
        strategy.addCollateral(address(wBTC), 8);
        strategy.addCollateral(address(tBTC), 8);
        vm.stopPrank();

        // Mint tokens to users
        sovaBTC.mint(user1, 100e8); // 100 BTC
        wBTC.mint(user1, 100e8);
        tBTC.mint(user1, 100e8);

        sovaBTC.mint(user2, 100e8);
        wBTC.mint(user2, 100e8);
        tBTC.mint(user2, 100e8);

        // Mint sovaBTC to manager for liquidity
        sovaBTC.mint(manager, 1000e8);
    }

    function test_DepositWBTC() public {
        uint256 depositAmount = 10e8; // 10 BTC

        vm.startPrank(user1);
        wBTC.approve(address(vaultToken), depositAmount);

        uint256 sharesBefore = vaultToken.balanceOf(user1);
        uint256 shares = vaultToken.depositCollateral(address(wBTC), depositAmount, user1);
        uint256 sharesAfter = vaultToken.balanceOf(user1);

        assertEq(shares, depositAmount * 1e10); // 8 decimals -> 18 decimals
        assertEq(sharesAfter - sharesBefore, shares);
        assertEq(wBTC.balanceOf(address(strategy)), depositAmount);
        vm.stopPrank();
    }

    function test_DepositTBTC() public {
        uint256 depositAmount = 5e8; // 5 BTC

        vm.startPrank(user1);
        tBTC.approve(address(vaultToken), depositAmount);

        uint256 shares = vaultToken.depositCollateral(address(tBTC), depositAmount, user1);

        assertEq(shares, depositAmount * 1e10); // 8 decimals -> 18 decimals
        assertEq(vaultToken.balanceOf(user1), shares);
        assertEq(tBTC.balanceOf(address(strategy)), depositAmount);
        vm.stopPrank();
    }

    function test_ManagedRedemption() public {
        // Setup: Add liquidity to strategy and approve token
        vm.startPrank(manager);
        sovaBTC.approve(address(strategy), 100e8);
        strategy.addLiquidity(100e8);
        // Approve token to withdraw from strategy
        strategy.approveTokenWithdrawal();
        vm.stopPrank();

        // User deposits wBTC
        uint256 depositAmount = 10e8; // 10 BTC
        vm.startPrank(user1);
        wBTC.approve(address(vaultToken), depositAmount);
        uint256 shares = vaultToken.depositCollateral(address(wBTC), depositAmount, user1);

        // User approves strategy to spend their shares for managed withdrawal
        vaultToken.approve(address(strategy), shares);
        vm.stopPrank();

        // Manager (as strategy) processes redemption
        vm.startPrank(address(strategy));
        uint256 sovaBTCBefore = sovaBTC.balanceOf(user1);

        // Redemption through ManagedWithdrawRWA (called by strategy)
        uint256 assets = ManagedWithdrawRWA(address(vaultToken)).redeem(
            shares,
            user1, // to
            user1, // owner
            depositAmount // minAssets (expecting 1:1)
        );

        uint256 sovaBTCAfter = sovaBTC.balanceOf(user1);

        assertEq(assets, depositAmount); // 1:1 conversion
        assertEq(sovaBTCAfter - sovaBTCBefore, assets);
        assertEq(vaultToken.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function test_MultipleDeposits() public {
        // User1 deposits wBTC
        vm.startPrank(user1);
        wBTC.approve(address(vaultToken), 5e8);
        vaultToken.depositCollateral(address(wBTC), 5e8, user1);
        vm.stopPrank();

        // User2 deposits tBTC
        vm.startPrank(user2);
        tBTC.approve(address(vaultToken), 3e8);
        vaultToken.depositCollateral(address(tBTC), 3e8, user2);
        vm.stopPrank();

        // Check total assets in strategy
        uint256 totalAssets = strategy.totalCollateralAssets();
        assertEq(totalAssets, 8e8); // 5 + 3 BTC

        // Check individual balances
        assertEq(strategy.collateralBalance(address(wBTC)), 5e8);
        assertEq(strategy.collateralBalance(address(tBTC)), 3e8);
    }

    function test_DirectCollateralDeposit() public {
        // Users can also deposit directly to strategy
        vm.startPrank(user1);
        wBTC.approve(address(strategy), 2e8);
        strategy.depositCollateral(address(wBTC), 2e8);
        vm.stopPrank();

        assertEq(wBTC.balanceOf(address(strategy)), 2e8);
    }

    function test_LiquidityManagement() public {
        vm.startPrank(manager);

        // Add liquidity
        sovaBTC.approve(address(strategy), 50e8);
        strategy.addLiquidity(50e8);
        assertEq(strategy.getAvailableLiquidity(), 50e8);

        // Remove some liquidity
        strategy.removeLiquidity(20e8, manager);
        assertEq(strategy.getAvailableLiquidity(), 30e8);

        vm.stopPrank();
    }

    function test_UnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 8);
        unsupportedToken.mint(user1, 10e8);

        vm.startPrank(user1);
        unsupportedToken.approve(address(vaultToken), 1e8);
        vm.expectRevert(BtcVaultToken.TokenNotSupported.selector);
        vaultToken.depositCollateral(address(unsupportedToken), 1e8, user1);
        vm.stopPrank();
    }

    function test_MinimumDeposit() public {
        vm.startPrank(user1);
        wBTC.approve(address(vaultToken), 1e5);

        // Try to deposit less than minimum (0.001 BTC = 1e5)
        vm.expectRevert(BtcVaultToken.InsufficientAmount.selector);
        vaultToken.depositCollateral(address(wBTC), 1e4, user1);

        // Minimum should work
        vaultToken.depositCollateral(address(wBTC), 1e5, user1);
        vm.stopPrank();
    }

    function test_StandardDepositDisabled() public {
        vm.startPrank(user1);
        sovaBTC.approve(address(vaultToken), 1e8);

        // Standard ERC-4626 deposit should be disabled
        vm.expectRevert(BtcVaultToken.StandardDepositDisabled.selector);
        vaultToken.deposit(1e8, user1);

        // Standard mint should also be disabled
        vm.expectRevert(BtcVaultToken.StandardDepositDisabled.selector);
        vaultToken.mint(1e18, user1);

        // Withdraw and redeem are restricted to strategy only (handled by parent class)
        // The error is NotStrategyAdmin from tRWA's onlyStrategy modifier
        vm.expectRevert(bytes4(keccak256("NotStrategyAdmin()")));
        vaultToken.withdraw(1e8, user1, user1);

        vm.stopPrank();
    }
}
