// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {ManagedWithdrawRWA} from "../src/token/ManagedWithdrawRWA.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockStrategy} from "../src/mocks/MockStrategy.sol";
import {MockRegistry} from "../src/mocks/MockRegistry.sol";
import {MockConduit} from "../src/mocks/MockConduit.sol";

/**
 * @title ManagedWithdrawRWATest
 * @notice Comprehensive tests for ManagedWithdrawRWA contract to achieve 100% coverage
 */
contract ManagedWithdrawRWATest is BaseFountfiTest {
    ManagedWithdrawRWA internal managedToken;
    MockStrategy internal strategy;
    MockRegistry internal mockRegistry;
    MockConduit internal mockConduit;

    // Test constants
    uint256 internal constant INITIAL_SUPPLY = 10000 * 10**6; // 10,000 USDC
    uint256 internal constant REDEEM_AMOUNT = 1000 * 10**6; // 1,000 USDC

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        // Create mock registry and conduit
        mockRegistry = new MockRegistry();
        mockConduit = new MockConduit();
        mockRegistry.setConduit(address(mockConduit));
        mockRegistry.setAsset(address(usdc), 6);

        // Deploy strategy
        strategy = new MockStrategy();
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            ""
        );
        
        // Mock the strategy's registry call to return our mock registry
        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(bytes4(keccak256("registry()"))),
            abi.encode(address(mockRegistry))
        );

        // Deploy ManagedWithdrawRWA token directly (since MockStrategy creates regular tRWA)
        managedToken = new ManagedWithdrawRWA(
            "Managed RWA",
            "MRWA",
            address(usdc),
            6,
            address(strategy)
        );

        // Setup initial balances
        usdc.mint(alice, INITIAL_SUPPLY);
        usdc.mint(bob, INITIAL_SUPPLY);
        usdc.mint(charlie, INITIAL_SUPPLY);
        usdc.mint(address(strategy), INITIAL_SUPPLY * 3);

        vm.stopPrank();

        // Strategy needs to approve the ManagedWithdrawRWA to transfer assets during redemptions
        vm.prank(address(strategy));
        usdc.approve(address(managedToken), type(uint256).max);

        // Don't setup initial deposits in setUp to avoid complications
        // Tests can set them up individually as needed
    }

    // ============ Constructor Tests ============

    function test_Constructor() public {
        ManagedWithdrawRWA newToken = new ManagedWithdrawRWA(
            "Test Token",
            "TEST",
            address(usdc),
            6,
            address(strategy)
        );

        assertEq(newToken.name(), "Test Token");
        assertEq(newToken.symbol(), "TEST");
        assertEq(newToken.asset(), address(usdc));
        assertEq(newToken.decimals(), 18); // ERC4626 always uses 18 decimals
        assertEq(newToken.strategy(), address(strategy));
    }

    // ============ Withdrawal Restriction Tests ============

    function test_Withdraw_AlwaysReverts() public {
        uint256 assets = 1000 * 10**6;

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.UseRedeem.selector);
        managedToken.withdraw(assets, alice, alice);
    }

    function test_Withdraw_AlwaysRevertsWithDifferentParams() public {
        uint256 assets = 500 * 10**6;

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.UseRedeem.selector);
        managedToken.withdraw(assets, bob, charlie);
    }

    // ============ Redemption Tests ============

    function test_Redeem_Success() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 sharesToRedeem = userShares / 2;
        uint256 expectedAssets = managedToken.previewRedeem(sharesToRedeem);

        // Alice must approve strategy to spend her shares
        vm.prank(alice);
        managedToken.approve(address(strategy), sharesToRedeem);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        vm.prank(address(strategy));
        uint256 assetsRedeemed = managedToken.redeem(sharesToRedeem, alice, alice);

        assertEq(assetsRedeemed, expectedAssets);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + assetsRedeemed);
        assertEq(managedToken.balanceOf(alice), userShares - sharesToRedeem);
    }

    function test_Redeem_ExceedsMaxRedeem() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 maxRedeemable = managedToken.maxRedeem(alice);
        uint256 excessiveShares = maxRedeemable + 1;

        vm.prank(alice);
        managedToken.approve(address(strategy), excessiveShares);

        vm.prank(address(strategy));
        vm.expectRevert(); // Should revert with RedeemMoreThanMax
        managedToken.redeem(excessiveShares, alice, alice);
    }

    function test_Redeem_UnauthorizedCaller() public {
        uint256 sharesToRedeem = 1000;

        vm.prank(alice); // Not strategy
        vm.expectRevert(); // Should revert - only strategy can call
        managedToken.redeem(sharesToRedeem, alice, alice);
    }

    function test_Redeem_WithMinAssets_Success() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 sharesToRedeem = userShares / 3;
        uint256 expectedAssets = managedToken.previewRedeem(sharesToRedeem);
        uint256 minAssets = expectedAssets - 100; // Set minimum slightly below expected

        vm.prank(alice);
        managedToken.approve(address(strategy), sharesToRedeem);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        vm.prank(address(strategy));
        uint256 assetsRedeemed = managedToken.redeem(sharesToRedeem, alice, alice, minAssets);

        assertEq(assetsRedeemed, expectedAssets);
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + assetsRedeemed);
        assertEq(managedToken.balanceOf(alice), userShares - sharesToRedeem);
    }

    function test_Redeem_WithMinAssets_InsufficientAssets() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 sharesToRedeem = userShares / 3;
        uint256 expectedAssets = managedToken.previewRedeem(sharesToRedeem);
        uint256 minAssets = expectedAssets + 1000; // Set minimum above expected

        vm.prank(alice);
        managedToken.approve(address(strategy), sharesToRedeem);

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InsufficientOutputAssets.selector);
        managedToken.redeem(sharesToRedeem, alice, alice, minAssets);
    }

    function test_Redeem_WithMinAssets_ExceedsMaxRedeem() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 maxRedeemable = managedToken.maxRedeem(alice);
        uint256 excessiveShares = maxRedeemable + 1;
        uint256 minAssets = 0;

        vm.prank(alice);
        managedToken.approve(address(strategy), excessiveShares);

        vm.prank(address(strategy));
        vm.expectRevert(); // Should revert with RedeemMoreThanMax
        managedToken.redeem(excessiveShares, alice, alice, minAssets);
    }

    // ============ Batch Redemption Tests ============

    function test_BatchRedeemShares_Success() public {
        // Setup initial deposits for all users
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        _depositAsUser(bob, INITIAL_SUPPLY / 3);
        _depositAsUser(charlie, INITIAL_SUPPLY / 4);
        
        // Setup batch redemption for multiple users
        uint256[] memory shares = new uint256[](3);
        address[] memory recipients = new address[](3);
        address[] memory owners = new address[](3);
        uint256[] memory minAssets = new uint256[](3);

        shares[0] = managedToken.balanceOf(alice) / 2;
        shares[1] = managedToken.balanceOf(bob) / 3;
        shares[2] = managedToken.balanceOf(charlie) / 4;

        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        owners[0] = alice;
        owners[1] = bob;
        owners[2] = charlie;

        minAssets[0] = managedToken.previewRedeem(shares[0]) - 100;
        minAssets[1] = managedToken.previewRedeem(shares[1]) - 50;
        minAssets[2] = managedToken.previewRedeem(shares[2]) - 25;

        // Users approve strategy
        vm.prank(alice);
        managedToken.approve(address(strategy), shares[0]);
        vm.prank(bob);
        managedToken.approve(address(strategy), shares[1]);
        vm.prank(charlie);
        managedToken.approve(address(strategy), shares[2]);

        // Record balances before
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);
        uint256 charlieBalanceBefore = usdc.balanceOf(charlie);

        uint256 aliceSharesBefore = managedToken.balanceOf(alice);
        uint256 bobSharesBefore = managedToken.balanceOf(bob);
        uint256 charlieSharesBefore = managedToken.balanceOf(charlie);

        vm.prank(address(strategy));
        uint256[] memory assetsRedeemed = managedToken.batchRedeemShares(shares, recipients, owners, minAssets);

        // Verify assets were transferred correctly
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + assetsRedeemed[0]);
        assertEq(usdc.balanceOf(bob), bobBalanceBefore + assetsRedeemed[1]);
        assertEq(usdc.balanceOf(charlie), charlieBalanceBefore + assetsRedeemed[2]);

        // Verify shares were burned
        assertEq(managedToken.balanceOf(alice), aliceSharesBefore - shares[0]);
        assertEq(managedToken.balanceOf(bob), bobSharesBefore - shares[1]);
        assertEq(managedToken.balanceOf(charlie), charlieSharesBefore - shares[2]);

        // Verify assets are reasonable
        assertGt(assetsRedeemed[0], minAssets[0]);
        assertGt(assetsRedeemed[1], minAssets[1]);
        assertGt(assetsRedeemed[2], minAssets[2]);
    }

    function test_BatchRedeemShares_InvalidArrayLengths() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory recipients = new address[](3); // Different length
        address[] memory owners = new address[](2);
        uint256[] memory minAssets = new uint256[](2);

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InvalidArrayLengths.selector);
        managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_InvalidArrayLengthsOwners() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory recipients = new address[](2);
        address[] memory owners = new address[](3); // Different length
        uint256[] memory minAssets = new uint256[](2);

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InvalidArrayLengths.selector);
        managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_InvalidArrayLengthsMinAssets() public {
        uint256[] memory shares = new uint256[](2);
        address[] memory recipients = new address[](2);
        address[] memory owners = new address[](2);
        uint256[] memory minAssets = new uint256[](1); // Different length

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InvalidArrayLengths.selector);
        managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_InsufficientAssets() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256[] memory shares = new uint256[](1);
        address[] memory recipients = new address[](1);
        address[] memory owners = new address[](1);
        uint256[] memory minAssets = new uint256[](1);

        shares[0] = managedToken.balanceOf(alice) / 2;
        recipients[0] = alice;
        owners[0] = alice;
        minAssets[0] = managedToken.previewRedeem(shares[0]) + 1000000; // Set unreasonably high

        vm.prank(alice);
        managedToken.approve(address(strategy), shares[0]);

        vm.prank(address(strategy));
        vm.expectRevert(ManagedWithdrawRWA.InsufficientOutputAssets.selector);
        managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_UnauthorizedCaller() public {
        uint256[] memory shares = new uint256[](1);
        address[] memory recipients = new address[](1);
        address[] memory owners = new address[](1);
        uint256[] memory minAssets = new uint256[](1);

        vm.prank(alice); // Not strategy
        vm.expectRevert(); // Should revert - only strategy can call
        managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
    }

    function test_BatchRedeemShares_EmptyArrays() public {
        uint256[] memory shares = new uint256[](0);
        address[] memory recipients = new address[](0);
        address[] memory owners = new address[](0);
        uint256[] memory minAssets = new uint256[](0);

        vm.prank(address(strategy));
        uint256[] memory assetsRedeemed = managedToken.batchRedeemShares(shares, recipients, owners, minAssets);
        
        assertEq(assetsRedeemed.length, 0);
    }

    // ============ Asset Collection Tests ============

    function test_Collect_Internal() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        // This tests the internal _collect function indirectly through redeem
        uint256 userShares = managedToken.balanceOf(alice);
        uint256 sharesToRedeem = userShares / 4;

        vm.prank(alice);
        managedToken.approve(address(strategy), sharesToRedeem);

        uint256 strategyBalanceBefore = usdc.balanceOf(address(strategy));
        uint256 tokenBalanceBefore = usdc.balanceOf(address(managedToken));

        vm.prank(address(strategy));
        managedToken.redeem(sharesToRedeem, alice, alice);

        // Verify assets were collected from strategy to token contract
        uint256 assetsCollected = managedToken.previewRedeem(sharesToRedeem);
        // Allow for rounding errors (1 wei)
        assertApproxEqAbs(usdc.balanceOf(address(strategy)), strategyBalanceBefore - assetsCollected, 1);
        // Note: Token contract balance should be 0 after transfer to alice
        assertEq(usdc.balanceOf(address(managedToken)), 0);
    }

    // ============ Integration Tests ============

    function test_CompleteRedemptionFlow() public {
        // Setup initial deposit
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        
        uint256 initialAliceShares = managedToken.balanceOf(alice);
        uint256 initialAliceAssets = usdc.balanceOf(alice);

        // Redeem all of Alice's shares
        vm.prank(alice);
        managedToken.approve(address(strategy), initialAliceShares);

        vm.prank(address(strategy));
        uint256 assetsRedeemed = managedToken.redeem(initialAliceShares, alice, alice);

        // Alice should have no shares left
        assertEq(managedToken.balanceOf(alice), 0);
        
        // Alice should have received assets
        assertEq(usdc.balanceOf(alice), initialAliceAssets + assetsRedeemed);
        
        // Verify assets redeemed is reasonable (should be close to what she originally deposited)
        assertGt(assetsRedeemed, 0);
    }

    function test_ProportionalRedemption() public {
        // Setup initial deposits
        _depositAsUser(alice, INITIAL_SUPPLY / 2);
        _depositAsUser(bob, INITIAL_SUPPLY / 3);
        
        // Test that redemption amounts are proportional to shares
        uint256 aliceShares = managedToken.balanceOf(alice);
        uint256 bobShares = managedToken.balanceOf(bob);

        uint256 aliceRedeem = aliceShares / 2;
        uint256 bobRedeem = bobShares / 2;

        vm.prank(alice);
        managedToken.approve(address(strategy), aliceRedeem);
        vm.prank(bob);
        managedToken.approve(address(strategy), bobRedeem);

        vm.prank(address(strategy));
        uint256 aliceAssets = managedToken.redeem(aliceRedeem, alice, alice);

        vm.prank(address(strategy));
        uint256 bobAssets = managedToken.redeem(bobRedeem, bob, bob);

        // The ratio of assets should be close to the ratio of shares
        // (allowing for small rounding differences)
        uint256 expectedRatio = (aliceRedeem * 1e18) / bobRedeem;
        uint256 actualRatio = (aliceAssets * 1e18) / bobAssets;
        
        // Allow 1% difference for rounding
        uint256 diff = expectedRatio > actualRatio ? expectedRatio - actualRatio : actualRatio - expectedRatio;
        assertLt(diff, expectedRatio / 100); // Less than 1% difference
    }

    // ============ Helper Functions ============

    function _depositAsUser(address user, uint256 amount) internal {
        // ManagedWithdrawRWA inherits from tRWA, so it should support deposits
        // The key is that withdrawals are restricted, not deposits
        vm.startPrank(user);
        usdc.approve(address(mockConduit), amount);
        managedToken.deposit(amount, user);
        vm.stopPrank();
    }
}