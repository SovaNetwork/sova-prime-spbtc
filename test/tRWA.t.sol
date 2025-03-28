// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";

contract tRWATest is Test {
    tRWA public token;
    NavOracle public oracle;
    tRWAFactory public factory;
    address public mockUnderlyingAsset;
    address public mockTransferApproval;

    address public user1 = address(2);
    address public user2 = address(3);

    uint256 public initialUnderlying = 1e18; // $1.00 per token

    function setUp() public {
        // Deploy contracts
        // Create a mock initial token for the oracle
        mockUnderlyingAsset = address(0xDADA);
        mockTransferApproval = address(0xDEAD);
        address mockInitialToken = address(0xDEDB); // Mock token address for oracle

        // Deploy oracle with mock token address and initial price
        oracle = new NavOracle(mockInitialToken, initialUnderlying);

        // The test contract is already an authorized updater through the constructor
        // but we need to make sure it has explicit authorization as the test runs
        assertTrue(oracle.authorizedUpdaters(address(this)), "Test contract not authorized in oracle");

        // Deploy factory with initial approved implementations
        factory = new tRWAFactory();

        // Approve implementations in the factory
        factory.setOracleApproval(address(oracle), true);
        factory.setSubscriptionManagerApproval(address(this), true);
        factory.setUnderlyingAssetApproval(mockUnderlyingAsset, true);
        factory.setTransferApprovalApproval(mockTransferApproval, true);

        // Update the factory to be the admin of the oracle
        oracle.transferOwnership(address(factory));

        // Deploy a test token through the factory with the specified implementations
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            address(oracle),
            address(this),
            mockUnderlyingAsset,
            address(0) // No transfer approval initially
        );
        token = tRWA(tokenAddress);

        // Mint some tokens to users for testing
        token.deposit(1000e18, user1);
        token.deposit(500e18, user2);
    }

    function test_InitialState() public {
        // Check initial token state
        assertEq(token.name(), "Tokenized Real Estate Fund");
        assertEq(token.symbol(), "TREF");
        assertEq(token.underlyingPerToken(), initialUnderlying);

        // Check initial balances
        assertEq(token.balanceOf(user1), 1000e18);
        assertEq(token.balanceOf(user2), 500e18);
        assertEq(token.totalSupply(), 1500e18);
    }

    function test_UnderlyingValueUpdate() public {
        uint256 newValue = 1.05e18; // $1.05 per token

        // Update underlying value through the oracle
        oracle.updateUnderlyingValue(newValue, "Test Update");

        // Check if underlying value was updated
        assertEq(token.underlyingPerToken(), newValue);

        // Check USD value calculation
        assertEq(token.getUsdValue(1000e18), 1050e18); // $1,050 for 1000 shares
    }

    function test_MultipleTRWAsWithSameOracle() public {
        // Deploy a second token with the same oracle but different subscription manager
        address secondSubscriptionManager = address(0x789);
        factory.setSubscriptionManagerApproval(secondSubscriptionManager, true);

        address secondTokenAddress = factory.deployToken(
            "Second Tokenized Fund",
            "STF",
            address(oracle),
            secondSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );
        tRWA secondToken = tRWA(secondTokenAddress);

        // Check that the second token is properly configured
        assertEq(secondToken.underlyingPerToken(), initialUnderlying);
        assertTrue(secondToken.hasAnyRole(secondSubscriptionManager, secondToken.SUBSCRIPTION_ROLE()));

        // Update underlying value only for the second token
        oracle.updateUnderlyingValue(2.5e18, "Second Token Update");

        // First token should remain unchanged
        assertEq(token.underlyingPerToken(), initialUnderlying);

        // Second token should be updated
        assertEq(secondToken.underlyingPerToken(), 2.5e18);
    }

    function test_MultipleTRWAsWithDifferentOracles() public {
        // Deploy a second oracle
        address mockSecondToken = address(0xBEDB);
        NavOracle secondOracle = new NavOracle(mockSecondToken, 1e18);
        assertTrue(secondOracle.authorizedUpdaters(address(this)), "Test contract not authorized in second oracle");
        secondOracle.transferOwnership(address(factory));

        // Approve the second oracle in the factory
        factory.setOracleApproval(address(secondOracle), true);

        // Deploy a token with the second oracle
        address secondTokenAddress = factory.deployToken(
            "Alternative Tokenized Fund",
            "ATF",
            address(secondOracle),
            address(this), // Same subscription manager
            mockUnderlyingAsset,
            mockTransferApproval // Use transfer approval
        );
        tRWA secondToken = tRWA(secondTokenAddress);

        // Check that the token uses the second oracle
        assertTrue(secondToken.hasAnyRole(address(secondOracle), secondToken.PRICE_AUTHORITY_ROLE()));

        // Check that the transfer approval is set and enabled
        assertEq(secondToken.transferApproval(), mockTransferApproval);
        assertTrue(secondToken.transferApprovalEnabled());

        // Update value through the second oracle
        secondOracle.updateUnderlyingValue(3.5e18, "Second Oracle Update");

        // First token should remain unchanged (different oracle)
        assertEq(token.underlyingPerToken(), initialUnderlying);

        // Second token should be updated
        assertEq(secondToken.underlyingPerToken(), 3.5e18);
    }

    function test_TokenWithTransferApproval() public {
        // Deploy a token with transfer approval
        address tokenWithApprovalAddress = factory.deployToken(
            "Token With Transfer Approval",
            "TWTA",
            address(oracle),
            address(this),
            mockUnderlyingAsset,
            mockTransferApproval
        );
        tRWA tokenWithApproval = tRWA(tokenWithApprovalAddress);

        // Check transfer approval is set and enabled
        assertEq(tokenWithApproval.transferApproval(), mockTransferApproval);
        assertTrue(tokenWithApproval.transferApprovalEnabled());

        // Test disabling transfer approval
        tokenWithApproval.toggleTransferApproval(false);
        assertFalse(tokenWithApproval.transferApprovalEnabled());

        // Test changing transfer approval
        address newTransferApproval = address(0xBEEF);
        factory.setTransferApprovalApproval(newTransferApproval, true);

        tokenWithApproval.setTransferApproval(newTransferApproval);
        assertEq(tokenWithApproval.transferApproval(), newTransferApproval);
    }

    function test_UnauthorizedValueUpdate() public {
        uint256 newValue = 1.05e18; // $1.05 per token

        // Try to update underlying value directly (should fail)
        vm.startPrank(user1);
        vm.expectRevert();
        token.updateUnderlyingValue(newValue);
        vm.stopPrank();

        // Try to update underlying value through oracle as unauthorized user (should fail)
        vm.startPrank(user2);
        vm.expectRevert();
        oracle.updateUnderlyingValue(newValue, "Unauthorized Update");
        vm.stopPrank();
    }

    function test_TokenMintAndBurn() public {
        // Mint new tokens
        uint256 assetsToDeposit = 500e18;
        token.deposit(assetsToDeposit, user1);
        assertEq(token.balanceOf(user1), 1500e18);
        assertEq(token.totalSupply(), 2000e18);

        // Burn tokens
        uint256 sharesToRedeem = 300e18;
        token.redeem(sharesToRedeem, address(this), user1);
        assertEq(token.balanceOf(user1), 1200e18);
        assertEq(token.totalSupply(), 1700e18);
    }

    function test_UnauthorizedMintAndBurn() public {
        vm.startPrank(user1);

        // Try to mint tokens (should fail)
        vm.expectRevert();
        token.deposit(500e18, user1);

        // Try to burn tokens (should fail)
        vm.expectRevert();
        token.redeem(100e18, user1, user1);

        vm.stopPrank();
    }

    function testFuzz_UnderlyingValueCalculation(uint256 shares, uint256 underlying) public {
        // Bound inputs to reasonable ranges to avoid overflows
        shares = bound(shares, 1, 1e24);
        underlying = bound(underlying, 1e6, 1e20);

        oracle.updateUnderlyingValue(underlying, "Fuzz Test Update");

        uint256 expectedUsdValue = (shares * underlying) / 1e18;
        assertEq(token.getUsdValue(shares), expectedUsdValue);
    }
}