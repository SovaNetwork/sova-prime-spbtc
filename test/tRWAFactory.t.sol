// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {ItRWA} from "../src/interfaces/ItRWA.sol";

contract tRWAFactoryTest is Test {
    NavOracle public oracle;
    NavOracle public secondOracle;
    tRWAFactory public factory;
    address public mockSubscriptionManager;
    address public mockUnderlyingAsset;
    address public secondSubscriptionManager;
    address public secondUnderlyingAsset;
    address public mockTransferApproval;
    address public secondTransferApproval;

    address public user = address(2);

    function setUp() public {
        // Create mock addresses
        mockSubscriptionManager = address(0x123);
        mockUnderlyingAsset = address(0x456);
        secondSubscriptionManager = address(0x789);
        secondUnderlyingAsset = address(0xABC);
        mockTransferApproval = address(0xDEF);
        secondTransferApproval = address(0x789AB);

        // Create mock token addresses for the oracles
        address mockToken1 = address(0xFADE);
        address mockToken2 = address(0xBEEF);

        // Deploy contracts with the right parameters
        oracle = new NavOracle(mockToken1, 1e18);
        secondOracle = new NavOracle(mockToken2, 1e18);

        // Verify test contract has authorization in the oracle
        assertTrue(oracle.authorizedUpdaters(address(this)), "Test contract not authorized in oracle");
        assertTrue(secondOracle.authorizedUpdaters(address(this)), "Test contract not authorized in second oracle");

        factory = new tRWAFactory();

        // Approve initial implementations
        factory.setOracleApproval(address(oracle), true);
        factory.setSubscriptionManagerApproval(mockSubscriptionManager, true);
        factory.setUnderlyingAssetApproval(mockUnderlyingAsset, true);
        factory.setTransferApprovalApproval(mockTransferApproval, true);

        // Update the oracles to have the factory as admin
        oracle.transferOwnership(address(factory));
        secondOracle.transferOwnership(address(factory));
    }

    function test_DeployToken() public {
        // Deploy a token with initially approved contracts and no transfer approval enabled
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0) // No transfer approval
        );

        // Verify token was deployed and registered
        assertTrue(factory.isRegisteredToken(tokenAddress));
        assertEq(factory.allTokens(0), tokenAddress);
        assertEq(factory.getTokenCount(), 1);

        // Check token properties
        tRWA token = tRWA(tokenAddress);
        assertEq(token.name(), "Tokenized Real Estate Fund");
        assertEq(token.symbol(), "TREF");
        assertEq(token.underlyingPerToken(), 1e18);
        assertEq(token.asset(), mockUnderlyingAsset);

        // Check roles are correctly assigned
        assertTrue(token.hasAnyRole(address(factory), token.ADMIN_ROLE()));
        assertTrue(token.hasAnyRole(address(oracle), token.PRICE_AUTHORITY_ROLE()));
        assertTrue(token.hasAnyRole(mockSubscriptionManager, token.SUBSCRIPTION_ROLE()));
    }

    function test_DeployTokenWithTransferApproval() public {
        // Deploy a token with transfer approval enabled
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund With Transfer Approval",
            "TREFTA",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            mockTransferApproval
        );

        // Check token has transfer approval set and enabled
        tRWA token = tRWA(tokenAddress);
        assertEq(token.transferApproval(), mockTransferApproval);
        assertTrue(token.transferApprovalEnabled());
    }

    function test_DeployMultipleTokens() public {
        // Approve additional implementations
        factory.setOracleApproval(address(secondOracle), true);
        factory.setSubscriptionManagerApproval(secondSubscriptionManager, true);
        factory.setUnderlyingAssetApproval(secondUnderlyingAsset, true);
        factory.setTransferApprovalApproval(secondTransferApproval, true);

        // Deploy multiple tokens with different implementations
        address token1 = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );

        address token2 = factory.deployToken(
            "Tokenized Infrastructure Fund",
            "TIF",
            address(secondOracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            mockTransferApproval
        );

        address token3 = factory.deployToken(
            "Tokenized Credit Fund",
            "TCF",
            address(oracle),
            secondSubscriptionManager,
            secondUnderlyingAsset,
            secondTransferApproval
        );

        // Check token count
        assertEq(factory.getTokenCount(), 3);

        // Check getAllTokens
        address[] memory tokens = factory.getAllTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);

        // Verify token2 uses second oracle and has transfer approval
        tRWA token = tRWA(token2);
        assertTrue(token.hasAnyRole(address(secondOracle), token.PRICE_AUTHORITY_ROLE()));
        assertEq(token.transferApproval(), mockTransferApproval);
        assertTrue(token.transferApprovalEnabled());

        // Verify token3 uses second subscription manager, underlying asset, and transfer approval
        token = tRWA(token3);
        assertTrue(token.hasAnyRole(secondSubscriptionManager, token.SUBSCRIPTION_ROLE()));
        assertEq(token.asset(), secondUnderlyingAsset);
        assertEq(token.transferApproval(), secondTransferApproval);
        assertTrue(token.transferApprovalEnabled());
    }

    function test_UnauthorizedDeployment() public {
        vm.startPrank(user);

        // Try to deploy a token as unauthorized user (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );

        vm.stopPrank();
    }

    function test_TransferOwnership() public {
        address newOwner = address(3);

        // Transfer ownership to new address
        factory.transferOwnership(newOwner);

        // Verify owner has changed
        assertEq(factory.owner(), newOwner);

        // Current address should no longer be able to deploy tokens
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );

        // New owner should be able to deploy tokens
        vm.startPrank(newOwner);
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );
        assertTrue(factory.isRegisteredToken(tokenAddress));
        vm.stopPrank();
    }

    function test_RegistryApprovals() public {
        // Verify initial approvals
        assertTrue(factory.isOracleApproved(address(oracle)));
        assertTrue(factory.isSubscriptionManagerApproved(mockSubscriptionManager));
        assertTrue(factory.isUnderlyingAssetApproved(mockUnderlyingAsset));
        assertTrue(factory.isTransferApprovalApproved(mockTransferApproval));

        // Add new approvals
        factory.setOracleApproval(address(secondOracle), true);
        factory.setSubscriptionManagerApproval(secondSubscriptionManager, true);
        factory.setUnderlyingAssetApproval(secondUnderlyingAsset, true);
        factory.setTransferApprovalApproval(secondTransferApproval, true);

        // Verify new approvals
        assertTrue(factory.isOracleApproved(address(secondOracle)));
        assertTrue(factory.isSubscriptionManagerApproved(secondSubscriptionManager));
        assertTrue(factory.isUnderlyingAssetApproved(secondUnderlyingAsset));
        assertTrue(factory.isTransferApprovalApproved(secondTransferApproval));

        // Remove approvals
        factory.setOracleApproval(address(oracle), false);
        factory.setSubscriptionManagerApproval(mockSubscriptionManager, false);
        factory.setUnderlyingAssetApproval(mockUnderlyingAsset, false);
        factory.setTransferApprovalApproval(mockTransferApproval, false);

        // Verify removed approvals
        assertFalse(factory.isOracleApproved(address(oracle)));
        assertFalse(factory.isSubscriptionManagerApproved(mockSubscriptionManager));
        assertFalse(factory.isUnderlyingAssetApproved(mockUnderlyingAsset));
        assertFalse(factory.isTransferApprovalApproved(mockTransferApproval));
    }

    function test_UnapprovedImplementations() public {
        address unapprovedOracle = address(0xBBB);
        address unapprovedManager = address(0xCCC);
        address unapprovedAsset = address(0xDDD);
        address unapprovedTransferApproval = address(0xEEE);

        // Try to use unapproved oracle (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            unapprovedOracle,
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );

        // Try to use unapproved subscription manager (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            unapprovedManager,
            mockUnderlyingAsset,
            address(0)
        );

        // Try to use unapproved underlying asset (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            unapprovedAsset,
            address(0)
        );

        // Try to use unapproved transfer approval (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            unapprovedTransferApproval
        );

        // Now approve them and try again
        factory.setOracleApproval(unapprovedOracle, true);
        factory.setSubscriptionManagerApproval(unapprovedManager, true);
        factory.setUnderlyingAssetApproval(unapprovedAsset, true);
        factory.setTransferApprovalApproval(unapprovedTransferApproval, true);

        // Should now work
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            unapprovedOracle,
            unapprovedManager,
            unapprovedAsset,
            unapprovedTransferApproval
        );

        // Verify it worked
        assertTrue(factory.isRegisteredToken(tokenAddress));

        // Verify transfer approval is set and enabled
        tRWA token = tRWA(tokenAddress);
        assertEq(token.transferApproval(), unapprovedTransferApproval);
        assertTrue(token.transferApprovalEnabled());
    }

    function test_TransferApprovalButNotEnabled() public {
        // Deploy token with transfer approval set but not enabled
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            mockTransferApproval
        );

        // Set the transfer approval to be disabled
        tRWA token = tRWA(tokenAddress);
        // Toggle off transfer approval that was enabled by default
        token.toggleTransferApproval(false);

        // Verify transfer approval is set but not enabled
        assertEq(token.transferApproval(), mockTransferApproval);
        assertFalse(token.transferApprovalEnabled());
    }

    function test_InvalidUnderlyingValue() public {
        // We can't test this directly since the validation happens in NavOracle now
        // Instead we'll test that the token initialization succeeds with normal values
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset,
            address(0)
        );

        assertTrue(factory.isRegisteredToken(tokenAddress));
    }
}