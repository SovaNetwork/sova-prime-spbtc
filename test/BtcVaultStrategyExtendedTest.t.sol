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
 * @title BtcVaultStrategyExtendedTest
 * @notice Extended test suite for improving coverage of BtcVaultStrategy
 * @dev Tests edge cases, error conditions, and admin functions
 */
contract BtcVaultStrategyExtendedTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public vaultToken;
    PriceOracleReporter public reporter;
    RoleManager public roleManager;
    
    MockERC20 public wbtc;
    MockERC20 public tbtc;
    MockERC20 public sovaBTC;
    MockERC20 public newToken;
    
    address public manager = address(0x1);
    address public user = address(0x2);
    address public admin = address(0x3);
    
    function setUp() public {
        // Deploy mock tokens
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        tbtc = new MockERC20("tBTC", "tBTC", 8);
        sovaBTC = new MockERC20("sovaBTC", "SOVABTC", 8);
        newToken = new MockERC20("New BTC", "NBTC", 8);
        
        // Deploy role manager
        roleManager = new RoleManager();
        roleManager.grantRole(manager, roleManager.STRATEGY_ADMIN());
        roleManager.grantRole(admin, roleManager.PROTOCOL_ADMIN());
        
        // Deploy reporter
        reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            manager, // Updater
            100, // Max deviation (1%)
            86400 // Time period (24 hours)
        );
        
        // Deploy strategy
        strategy = new BtcVaultStrategy();
        bytes memory initData = abi.encode(address(reporter));
        strategy.initialize(
            "BTC Vault Strategy",
            "BTC-STRAT",
            address(roleManager),
            manager,
            address(sovaBTC),
            8,
            initData
        );
        
        // The strategy automatically deploys BtcVaultToken during initialization
        vaultToken = BtcVaultToken(strategy.sToken());
        
        // Add initial collaterals (sovaBTC already added during initialization)
        vm.startPrank(manager);
        strategy.addCollateral(address(wbtc), 8);
        strategy.addCollateral(address(tbtc), 8);
        vm.stopPrank();
        
        // Mint tokens for testing
        wbtc.mint(user, 10e8);
        tbtc.mint(user, 10e8);
        sovaBTC.mint(user, 10e8);
        sovaBTC.mint(manager, 100e8);
        newToken.mint(user, 10e8);
    }
    
    /*//////////////////////////////////////////////////////////////
                        ERROR CONDITION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_AddCollateral_ZeroAddress() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidAddress.selector);
        strategy.addCollateral(address(0), 8);
        vm.stopPrank();
    }
    
    function test_AddCollateral_AlreadySupported() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.AssetAlreadySupported.selector);
        strategy.addCollateral(address(wbtc), 8);
        vm.stopPrank();
    }
    
    function test_AddCollateral_InvalidDecimals() public {
        MockERC20 wrongDecimalToken = new MockERC20("Wrong", "WRONG", 18);
        
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidDecimals.selector);
        strategy.addCollateral(address(wrongDecimalToken), 18);
        vm.stopPrank();
    }
    
    function test_AddCollateral_Unauthorized() public {
        vm.startPrank(user);
        vm.expectRevert();
        strategy.addCollateral(address(newToken), 8);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                    REMOVE COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_RemoveCollateral_Success() public {
        // First add a new collateral
        vm.startPrank(manager);
        strategy.addCollateral(address(newToken), 8);
        assertTrue(strategy.isSupportedAsset(address(newToken)));
        
        // Now remove it
        strategy.removeCollateral(address(newToken));
        assertFalse(strategy.isSupportedAsset(address(newToken)));
        vm.stopPrank();
        
        // Verify it was removed from the array
        address[] memory collaterals = strategy.getSupportedCollaterals();
        for (uint256 i = 0; i < collaterals.length; i++) {
            assertTrue(collaterals[i] != address(newToken));
        }
    }
    
    function test_RemoveCollateral_NotSupported() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.AssetNotSupported.selector);
        strategy.removeCollateral(address(newToken));
        vm.stopPrank();
    }
    
    function test_RemoveCollateral_CannotRemoveSovaBTC() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidAddress.selector);
        strategy.removeCollateral(address(sovaBTC));
        vm.stopPrank();
    }
    
    function test_RemoveCollateral_Unauthorized() public {
        vm.startPrank(user);
        vm.expectRevert();
        strategy.removeCollateral(address(wbtc));
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                    DEPOSIT COLLATERAL EDGE CASES
    //////////////////////////////////////////////////////////////*/
    
    function test_DepositCollateral_DirectToSovaBTC() public {
        // When depositing sovaBTC directly, it should increase availableLiquidity
        uint256 amount = 5e8;
        
        vm.startPrank(user);
        sovaBTC.approve(address(strategy), amount);
        
        uint256 liquidityBefore = strategy.availableLiquidity();
        strategy.depositCollateral(address(sovaBTC), amount);
        uint256 liquidityAfter = strategy.availableLiquidity();
        
        assertEq(liquidityAfter - liquidityBefore, amount);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                    REBALANCE COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_RebalanceCollateral_Success() public {
        vm.startPrank(manager);
        // This is a placeholder function, just check it doesn't revert and emits event
        vm.expectEmit(true, true, false, true);
        emit IBtcVaultStrategy.CollateralRebalanced(address(wbtc), address(tbtc), 1e8);
        strategy.rebalanceCollateral(address(wbtc), address(tbtc), 1e8);
        vm.stopPrank();
    }
    
    function test_RebalanceCollateral_FromTokenNotSupported() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.AssetNotSupported.selector);
        strategy.rebalanceCollateral(address(newToken), address(tbtc), 1e8);
        vm.stopPrank();
    }
    
    function test_RebalanceCollateral_ToTokenNotSupported() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.AssetNotSupported.selector);
        strategy.rebalanceCollateral(address(wbtc), address(newToken), 1e8);
        vm.stopPrank();
    }
    
    function test_RebalanceCollateral_ZeroAmount() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidAmount.selector);
        strategy.rebalanceCollateral(address(wbtc), address(tbtc), 0);
        vm.stopPrank();
    }
    
    function test_RebalanceCollateral_Unauthorized() public {
        vm.startPrank(user);
        vm.expectRevert();
        strategy.rebalanceCollateral(address(wbtc), address(tbtc), 1e8);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                    WITHDRAW COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_WithdrawCollateral_Success() public {
        // First deposit some collateral
        vm.startPrank(user);
        wbtc.approve(address(strategy), 5e8);
        strategy.depositCollateral(address(wbtc), 5e8);
        vm.stopPrank();
        
        // Now withdraw as manager
        vm.startPrank(manager);
        uint256 balanceBefore = wbtc.balanceOf(admin);
        
        vm.expectEmit(true, false, false, true);
        emit IBtcVaultStrategy.CollateralWithdrawn(address(wbtc), 3e8, admin);
        strategy.withdrawCollateral(address(wbtc), 3e8, admin);
        
        uint256 balanceAfter = wbtc.balanceOf(admin);
        assertEq(balanceAfter - balanceBefore, 3e8);
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_SovaBTC() public {
        // Add liquidity first
        vm.startPrank(manager);
        sovaBTC.approve(address(strategy), 10e8);
        strategy.addLiquidity(10e8);
        
        uint256 liquidityBefore = strategy.availableLiquidity();
        assertEq(liquidityBefore, 10e8);
        
        // Withdraw sovaBTC
        strategy.withdrawCollateral(address(sovaBTC), 5e8, admin);
        
        uint256 liquidityAfter = strategy.availableLiquidity();
        assertEq(liquidityAfter, 5e8);
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_TokenNotSupported() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.AssetNotSupported.selector);
        strategy.withdrawCollateral(address(newToken), 1e8, admin);
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_ZeroAmount() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidAmount.selector);
        strategy.withdrawCollateral(address(wbtc), 0, admin);
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_ZeroAddress() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InvalidAddress.selector);
        strategy.withdrawCollateral(address(wbtc), 1e8, address(0));
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_InsufficientBalance() public {
        vm.startPrank(manager);
        vm.expectRevert(IBtcVaultStrategy.InsufficientLiquidity.selector);
        strategy.withdrawCollateral(address(wbtc), 100e8, admin);
        vm.stopPrank();
    }
    
    function test_WithdrawCollateral_Unauthorized() public {
        vm.startPrank(user);
        vm.expectRevert();
        strategy.withdrawCollateral(address(wbtc), 1e8, admin);
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                    COLLATERAL ARRAY MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    
    function test_RemoveCollateral_FromMiddleOfArray() public {
        // Add multiple collaterals
        MockERC20 token1 = new MockERC20("Token1", "TK1", 8);
        MockERC20 token2 = new MockERC20("Token2", "TK2", 8);
        MockERC20 token3 = new MockERC20("Token3", "TK3", 8);
        
        vm.startPrank(manager);
        strategy.addCollateral(address(token1), 8);
        strategy.addCollateral(address(token2), 8);
        strategy.addCollateral(address(token3), 8);
        
        // Remove the middle one
        strategy.removeCollateral(address(token2));
        
        // Verify array integrity
        address[] memory collaterals = strategy.getSupportedCollaterals();
        bool foundToken2 = false;
        for (uint256 i = 0; i < collaterals.length; i++) {
            if (collaterals[i] == address(token2)) {
                foundToken2 = true;
                break;
            }
        }
        assertFalse(foundToken2);
        
        // Verify other tokens still exist
        assertTrue(strategy.isSupportedAsset(address(token1)));
        assertTrue(strategy.isSupportedAsset(address(token3)));
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                        EVENTS EMISSION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_Events_CollateralAdded() public {
        vm.startPrank(manager);
        vm.expectEmit(true, false, false, true);
        emit IBtcVaultStrategy.CollateralAdded(address(newToken), 8);
        strategy.addCollateral(address(newToken), 8);
        vm.stopPrank();
    }
    
    function test_Events_CollateralRemoved() public {
        vm.startPrank(manager);
        strategy.addCollateral(address(newToken), 8);
        
        vm.expectEmit(true, false, false, false);
        emit IBtcVaultStrategy.CollateralRemoved(address(newToken));
        strategy.removeCollateral(address(newToken));
        vm.stopPrank();
    }
}