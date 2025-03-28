// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
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

    address public user = address(2);

    function setUp() public {
        // Create mock addresses
        mockSubscriptionManager = address(0x123);
        mockUnderlyingAsset = address(0x456);
        secondSubscriptionManager = address(0x789);
        secondUnderlyingAsset = address(0xABC);

        // Deploy contracts
        oracle = new NavOracle();
        secondOracle = new NavOracle();

        // Verify test contract has authorization in the oracle
        assertTrue(oracle.authorizedUpdaters(address(this)), "Test contract not authorized in oracle");
        assertTrue(secondOracle.authorizedUpdaters(address(this)), "Test contract not authorized in second oracle");

        factory = new tRWAFactory(address(oracle), mockSubscriptionManager, mockUnderlyingAsset);

        // Update the oracles to have the factory as admin
        oracle.updateAdmin(address(factory));
        secondOracle.updateAdmin(address(factory));
    }

    function test_DeployToken() public {
        // Deploy a token with initially approved contracts
        address tokenAddress = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        // Verify token was deployed and registered
        assertTrue(factory.isRegisteredToken(tokenAddress));
        assertEq(factory.allTokens(0), tokenAddress);
        assertEq(factory.getTokenCount(), 1);

        // Verify token is registered in oracle
        assertTrue(oracle.supportedTokens(tokenAddress));

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

    function test_DeployMultipleTokens() public {
        // Approve additional implementations
        factory.setOracleApproval(address(secondOracle), true);
        factory.setSubscriptionManagerApproval(secondSubscriptionManager, true);
        factory.setUnderlyingAssetApproval(secondUnderlyingAsset, true);

        // Deploy multiple tokens with different implementations
        address token1 = factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        address token2 = factory.deployToken(
            "Tokenized Infrastructure Fund",
            "TIF",
            2e18,
            address(secondOracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        address token3 = factory.deployToken(
            "Tokenized Credit Fund",
            "TCF",
            0.5e18,
            address(oracle),
            secondSubscriptionManager,
            secondUnderlyingAsset
        );

        // Check token count
        assertEq(factory.getTokenCount(), 3);

        // Check getAllTokens
        address[] memory tokens = factory.getAllTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);

        // Verify token2 uses second oracle
        tRWA token = tRWA(token2);
        assertTrue(token.hasAnyRole(address(secondOracle), token.PRICE_AUTHORITY_ROLE()));

        // Verify token3 uses second subscription manager and underlying asset
        token = tRWA(token3);
        assertTrue(token.hasAnyRole(secondSubscriptionManager, token.SUBSCRIPTION_ROLE()));
        assertEq(token.asset(), secondUnderlyingAsset);
    }

    function test_UnauthorizedDeployment() public {
        vm.startPrank(user);

        // Try to deploy a token as unauthorized user (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Tokenized Real Estate Fund",
            "TREF",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        vm.stopPrank();
    }

    function test_UpdateAdmin() public {
        address newAdmin = address(3);

        // Update admin to new address
        factory.updateAdmin(newAdmin);
        assertEq(factory.admin(), newAdmin);

        // Current address should no longer be able to deploy tokens
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        // New admin should be able to deploy tokens
        vm.startPrank(newAdmin);
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );
        assertTrue(factory.isRegisteredToken(tokenAddress));
        vm.stopPrank();
    }

    function test_RegistryApprovals() public {
        // Verify initial approvals
        assertTrue(factory.isOracleApproved(address(oracle)));
        assertTrue(factory.isSubscriptionManagerApproved(mockSubscriptionManager));
        assertTrue(factory.isUnderlyingAssetApproved(mockUnderlyingAsset));

        // Add new approvals
        factory.setOracleApproval(address(secondOracle), true);
        factory.setSubscriptionManagerApproval(secondSubscriptionManager, true);
        factory.setUnderlyingAssetApproval(secondUnderlyingAsset, true);

        // Verify new approvals
        assertTrue(factory.isOracleApproved(address(secondOracle)));
        assertTrue(factory.isSubscriptionManagerApproved(secondSubscriptionManager));
        assertTrue(factory.isUnderlyingAssetApproved(secondUnderlyingAsset));

        // Remove approvals
        factory.setOracleApproval(address(oracle), false);
        factory.setSubscriptionManagerApproval(mockSubscriptionManager, false);
        factory.setUnderlyingAssetApproval(mockUnderlyingAsset, false);

        // Verify removed approvals
        assertFalse(factory.isOracleApproved(address(oracle)));
        assertFalse(factory.isSubscriptionManagerApproved(mockSubscriptionManager));
        assertFalse(factory.isUnderlyingAssetApproved(mockUnderlyingAsset));
    }

    function test_UnapprovedImplementations() public {
        address unapprovedOracle = address(0xBBB);
        address unapprovedManager = address(0xCCC);
        address unapprovedAsset = address(0xDDD);

        // Try to use unapproved oracle (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            unapprovedOracle,
            mockSubscriptionManager,
            mockUnderlyingAsset
        );

        // Try to use unapproved subscription manager (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            address(oracle),
            unapprovedManager,
            mockUnderlyingAsset
        );

        // Try to use unapproved underlying asset (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            address(oracle),
            mockSubscriptionManager,
            unapprovedAsset
        );

        // Now approve them and try again
        factory.setOracleApproval(unapprovedOracle, true);
        factory.setSubscriptionManagerApproval(unapprovedManager, true);
        factory.setUnderlyingAssetApproval(unapprovedAsset, true);

        // Should now work
        address tokenAddress = factory.deployToken(
            "Test Token",
            "TEST",
            1e18,
            unapprovedOracle,
            unapprovedManager,
            unapprovedAsset
        );

        // Verify it worked
        assertTrue(factory.isRegisteredToken(tokenAddress));
    }

    function test_InvalidUnderlyingValue() public {
        // Try to deploy a token with zero underlying value (should fail)
        vm.expectRevert();
        factory.deployToken(
            "Test Token",
            "TEST",
            0,
            address(oracle),
            mockSubscriptionManager,
            mockUnderlyingAsset
        );
    }
}