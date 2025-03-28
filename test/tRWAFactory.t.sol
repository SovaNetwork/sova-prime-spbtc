// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {tRWA} from "../src/token/tRWA.sol";
import {NavOracle} from "../src/token/NavOracle.sol";
import {tRWAFactory} from "../src/token/tRWAFactory.sol";
import {ItRWA} from "../src/interfaces/ItRWA.sol";

contract tRWAFactoryTest is Test {
    NavOracle public oracle;
    tRWAFactory public factory;
    address public mockSubscriptionManager;
    address public mockUnderlyingAsset;

    address public user = address(2);

    function setUp() public {
        // Create mock addresses
        mockSubscriptionManager = address(0x123);
        mockUnderlyingAsset = address(0x456);

        // Deploy contracts
        oracle = new NavOracle();

        // Verify test contract has authorization in the oracle
        assertTrue(oracle.authorizedUpdaters(address(this)), "Test contract not authorized in oracle");

        factory = new tRWAFactory(address(oracle), mockSubscriptionManager, mockUnderlyingAsset);

        // Update the factory to be the admin of the oracle
        oracle.updateAdmin(address(factory));
    }

    function test_DeployToken() public {
        // Deploy a token
        address tokenAddress = factory.deployToken("Tokenized Real Estate Fund", "TREF", 1e18);

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
        // Deploy multiple tokens
        address token1 = factory.deployToken("Tokenized Real Estate Fund", "TREF", 1e18);
        address token2 = factory.deployToken("Tokenized Infrastructure Fund", "TIF", 2e18);
        address token3 = factory.deployToken("Tokenized Credit Fund", "TCF", 0.5e18);

        // Check token count
        assertEq(factory.getTokenCount(), 3);

        // Check getAllTokens
        address[] memory tokens = factory.getAllTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);
    }

    function test_UnauthorizedDeployment() public {
        vm.startPrank(user);

        // Try to deploy a token as unauthorized user (should fail)
        vm.expectRevert();
        factory.deployToken("Tokenized Real Estate Fund", "TREF", 1e18);

        vm.stopPrank();
    }

    function test_UpdateAdmin() public {
        address newAdmin = address(3);

        // Update admin to new address
        factory.updateAdmin(newAdmin);
        assertEq(factory.admin(), newAdmin);

        // Current address should no longer be able to deploy tokens
        vm.expectRevert();
        factory.deployToken("Test Token", "TEST", 1e18);

        // New admin should be able to deploy tokens
        vm.startPrank(newAdmin);
        address tokenAddress = factory.deployToken("Test Token", "TEST", 1e18);
        assertTrue(factory.isRegisteredToken(tokenAddress));
        vm.stopPrank();
    }

    function test_UpdateOracle() public {
        // Deploy a new oracle
        NavOracle newOracle = new NavOracle();

        // Update the new oracle to have the factory as admin
        newOracle.updateAdmin(address(factory));

        // Update factory to use new oracle
        factory.updateOracle(address(newOracle));
        assertEq(address(factory.oracle()), address(newOracle));

        // Deploy a token with new oracle
        address tokenAddress = factory.deployToken("Test Token", "TEST", 1e18);

        // Verify token is registered in new oracle
        assertTrue(newOracle.supportedTokens(tokenAddress));

        // Verify token uses new oracle as price authority
        tRWA token = tRWA(tokenAddress);
        assertTrue(token.hasAnyRole(address(newOracle), token.PRICE_AUTHORITY_ROLE()));
    }

    function test_UpdateSubscriptionManager() public {
        address newSubscriptionManager = address(0xABC);

        // Update subscription manager
        factory.setSubscriptionManager(newSubscriptionManager);
        assertEq(factory.subscriptionManager(), newSubscriptionManager);

        // Deploy a token and verify it uses the new subscription manager
        address tokenAddress = factory.deployToken("Test Token", "TEST", 1e18);
        tRWA token = tRWA(tokenAddress);
        assertTrue(token.hasAnyRole(newSubscriptionManager, token.SUBSCRIPTION_ROLE()));
    }

    function test_UpdateUnderlyingAsset() public {
        address newUnderlyingAsset = address(0xDEF);

        // Update underlying asset
        factory.setUnderlyingAsset(newUnderlyingAsset);
        assertEq(factory.underlyingAsset(), newUnderlyingAsset);

        // Deploy a token and verify it uses the new underlying asset
        address tokenAddress = factory.deployToken("Test Token", "TEST", 1e18);
        tRWA token = tRWA(tokenAddress);
        assertEq(token.asset(), newUnderlyingAsset);
    }

    function test_InvalidUnderlyingValue() public {
        // Try to deploy a token with zero underlying value (should fail)
        vm.expectRevert();
        factory.deployToken("Test Token", "TEST", 0);
    }
}