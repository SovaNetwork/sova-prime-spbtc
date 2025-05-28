// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {GatedMintReportedStrategy} from "../src/strategy/GatedMintRWAStrategy.sol";
import {GatedMintRWA} from "../src/token/GatedMintRWA.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title GatedMintRWAStrategyTest
 * @notice Tests for GatedMintRWAStrategy contract to achieve 100% coverage
 */
contract GatedMintRWAStrategyTest is BaseFountfiTest {
    GatedMintReportedStrategy internal strategy;

    function setUp() public override {
        super.setUp();
    }

    function test_DeployToken() public {
        vm.prank(owner);
        strategy = new GatedMintReportedStrategy();

        // The _deployToken function is internal, so we test it through inheritance
        // by creating a test contract that exposes it
        TestGatedMintRWAStrategy testStrategy = new TestGatedMintRWAStrategy();

        address tokenAddress = testStrategy.deployTokenPublic(
            "Test Gated RWA",
            "TGRWA",
            address(usdc),
            6
        );

        // Verify the token was deployed correctly
        GatedMintRWA token = GatedMintRWA(tokenAddress);
        assertEq(token.name(), "Test Gated RWA");
        assertEq(token.symbol(), "TGRWA");
        assertEq(token.asset(), address(usdc));
        assertEq(token.strategy(), address(testStrategy));
        
        // Verify escrow was deployed
        assertTrue(token.escrow() != address(0));
    }
}

/**
 * @title TestGatedMintRWAStrategy
 * @notice Test contract to expose internal _deployToken function
 */
contract TestGatedMintRWAStrategy is GatedMintReportedStrategy {
    function deployTokenPublic(
        string calldata name_,
        string calldata symbol_,
        address asset_,
        uint8 assetDecimals_
    ) external returns (address) {
        return _deployToken(name_, symbol_, asset_, assetDecimals_);
    }
}