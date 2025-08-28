// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {RoleManager} from "../src/auth/RoleManager.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ItRWA} from "../src/token/ItRWA.sol";

/**
 * @title BtcVaultTokenExtendedTest
 * @notice Extended test suite for improving coverage of BtcVaultToken
 * @dev Tests constructor, preview functions, and error conditions
 */
contract BtcVaultTokenExtendedTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public vaultToken;
    PriceOracleReporter public reporter;
    RoleManager public roleManager;

    MockERC20 public wbtc;
    MockERC20 public tbtc;
    MockERC20 public sovaBTC;
    MockERC20 public unsupportedToken;

    address public manager = address(0x1);
    address public user = address(0x2);
    address public receiver = address(0x3);

    function setUp() public {
        // Deploy mock tokens
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 8);
        tbtc = new MockERC20("tBTC", "tBTC", 8);
        sovaBTC = new MockERC20("sovaBTC", "SOVABTC", 8);
        unsupportedToken = new MockERC20("Unsupported", "UNSUP", 8);

        // Deploy role manager
        roleManager = new RoleManager();
        roleManager.grantRole(manager, roleManager.STRATEGY_ADMIN());

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
            "BTC Vault Strategy", "BTC-STRAT", address(roleManager), manager, address(sovaBTC), 8, initData
        );

        // The strategy automatically deploys BtcVaultToken during initialization
        vaultToken = BtcVaultToken(strategy.sToken());

        // Add supported collaterals (sovaBTC already added during initialization)
        vm.startPrank(manager);
        strategy.addCollateral(address(wbtc));
        strategy.addCollateral(address(tbtc));
        vm.stopPrank();

        // Mint tokens for testing
        wbtc.mint(user, 100e8);
        tbtc.mint(user, 100e8);
        sovaBTC.mint(user, 100e8);
        unsupportedToken.mint(user, 100e8);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TokenProperties() public view {
        // Verify vault token properties
        assertEq(vaultToken.name(), "BTC Vault Strategy");
        assertEq(vaultToken.symbol(), "BTC-STRAT");
        assertEq(vaultToken.asset(), address(sovaBTC));
        assertEq(vaultToken.strategy(), address(strategy));
        assertEq(vaultToken.decimals(), 18); // Shares are always 18 decimals
    }

    /*//////////////////////////////////////////////////////////////
                    PREVIEW FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreviewDepositCollateral_Supported() public view {
        uint256 amount = 1e8; // 1 BTC
        // With NAV-aware logic at initial 1:1 price, shares should be 1e18
        uint256 expectedShares = 1e18; // NAV-aware calculation at 1:1 

        uint256 shares = vaultToken.previewDepositCollateral(address(wbtc), amount);
        assertEq(shares, expectedShares);
    }

    function test_PreviewDepositCollateral_Unsupported() public view {
        uint256 amount = 1e8;
        uint256 shares = vaultToken.previewDepositCollateral(address(unsupportedToken), amount);
        assertEq(shares, 0);
    }

    function test_PreviewDepositCollateral_BelowMinimum() public view {
        uint256 amount = vaultToken.MIN_DEPOSIT() - 1;
        uint256 shares = vaultToken.previewDepositCollateral(address(wbtc), amount);
        assertEq(shares, 0);
    }

    function test_PreviewDepositCollateral_ExactMinimum() public view {
        uint256 amount = vaultToken.MIN_DEPOSIT();
        uint256 expectedShares = amount * 10 ** 10;

        uint256 shares = vaultToken.previewDepositCollateral(address(wbtc), amount);
        assertEq(shares, expectedShares);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT COLLATERAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_DepositCollateral_UnsupportedToken() public {
        vm.startPrank(user);
        unsupportedToken.approve(address(vaultToken), 1e8);

        vm.expectRevert(BtcVaultToken.TokenNotSupported.selector);
        vaultToken.depositCollateral(address(unsupportedToken), 1e8, receiver);
        vm.stopPrank();
    }

    function test_DepositCollateral_BelowMinimum() public {
        uint256 amount = vaultToken.MIN_DEPOSIT() - 1;

        vm.startPrank(user);
        wbtc.approve(address(vaultToken), amount);

        vm.expectRevert(BtcVaultToken.InsufficientAmount.selector);
        vaultToken.depositCollateral(address(wbtc), amount, receiver);
        vm.stopPrank();
    }

    function test_DepositCollateral_ZeroReceiver() public {
        vm.startPrank(user);
        wbtc.approve(address(vaultToken), 1e8);

        vm.expectRevert(ItRWA.InvalidAddress.selector);
        vaultToken.depositCollateral(address(wbtc), 1e8, address(0));
        vm.stopPrank();
    }

    function test_DepositCollateral_ExactMinimum() public {
        uint256 amount = vaultToken.MIN_DEPOSIT();

        vm.startPrank(user);
        wbtc.approve(address(vaultToken), amount);

        uint256 sharesBefore = vaultToken.balanceOf(receiver);
        uint256 shares = vaultToken.depositCollateral(address(wbtc), amount, receiver);
        uint256 sharesAfter = vaultToken.balanceOf(receiver);

        assertEq(shares, amount * 10 ** 10);
        assertEq(sharesAfter - sharesBefore, shares);
        vm.stopPrank();
    }

    function test_DepositCollateral_LargeAmount() public {
        uint256 amount = 100e8; // 100 BTC

        vm.startPrank(user);
        wbtc.approve(address(vaultToken), amount);

        uint256 shares = vaultToken.depositCollateral(address(wbtc), amount, receiver);
        assertEq(shares, amount * 10 ** 10);
        assertEq(vaultToken.balanceOf(receiver), shares);
        vm.stopPrank();
    }

    function test_DepositCollateral_DifferentTokens() public {
        uint256 wbtcAmount = 2e8;
        uint256 tbtcAmount = 3e8;

        vm.startPrank(user);

        // Deposit WBTC
        wbtc.approve(address(vaultToken), wbtcAmount);
        uint256 wbtcShares = vaultToken.depositCollateral(address(wbtc), wbtcAmount, receiver);

        // Deposit TBTC
        tbtc.approve(address(vaultToken), tbtcAmount);
        uint256 tbtcShares = vaultToken.depositCollateral(address(tbtc), tbtcAmount, receiver);

        // Verify total shares
        uint256 totalShares = vaultToken.balanceOf(receiver);
        assertEq(totalShares, wbtcShares + tbtcShares);
        assertEq(totalShares, (wbtcAmount + tbtcAmount) * 10 ** 10);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    STANDARD DEPOSIT/MINT DISABLED
    //////////////////////////////////////////////////////////////*/

    function test_StandardDeposit_Disabled() public {
        vm.startPrank(user);
        sovaBTC.approve(address(vaultToken), 1e8);

        vm.expectRevert(BtcVaultToken.StandardDepositDisabled.selector);
        vaultToken.deposit(1e8, receiver);
        vm.stopPrank();
    }

    function test_StandardMint_Disabled() public {
        vm.startPrank(user);
        sovaBTC.approve(address(vaultToken), 1e8);

        vm.expectRevert(BtcVaultToken.StandardDepositDisabled.selector);
        vaultToken.mint(1e18, receiver);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Event_CollateralDeposited() public {
        uint256 amount = 1e8;
        uint256 expectedShares = amount * 10 ** 10;

        vm.startPrank(user);
        wbtc.approve(address(vaultToken), amount);

        vm.expectEmit(true, true, true, true);
        emit BtcVaultToken.CollateralDeposited(user, address(wbtc), amount, expectedShares, receiver);
        vaultToken.depositCollateral(address(wbtc), amount, receiver);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DECIMAL CONVERSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecimalConversion_8to18() public {
        // Test that 8-decimal collateral converts to 18-decimal shares correctly
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1; // Smallest unit
        amounts[1] = 1e5; // MIN_DEPOSIT
        amounts[2] = 1e8; // 1 BTC
        amounts[3] = 123456789; // Random amount
        amounts[4] = 21000000e8; // 21M BTC (max supply)

        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] >= vaultToken.MIN_DEPOSIT()) {
                uint256 expectedShares = amounts[i] * 10 ** 10;
                uint256 actualShares = vaultToken.previewDepositCollateral(address(wbtc), amounts[i]);
                assertEq(actualShares, expectedShares, "Decimal conversion failed");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        MIN DEPOSIT CONSTANT TEST
    //////////////////////////////////////////////////////////////*/

    function test_MinDepositConstant() public view {
        // Verify MIN_DEPOSIT is 0.001 BTC in 8 decimals
        assertEq(vaultToken.MIN_DEPOSIT(), 1e5);
    }
}
