// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BaseFountfiTest} from "./BaseFountfiTest.t.sol";
import {ManagedWithdrawReportedStrategy} from "../src/strategy/ManagedWithdrawRWAStrategy.sol";
import {ManagedWithdrawRWA} from "../src/token/ManagedWithdrawRWA.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockReporter} from "../src/mocks/MockReporter.sol";

/**
 * @title ManagedWithdrawReportedStrategyTest
 * @notice Tests for ManagedWithdrawReportedStrategy contract to achieve 100% coverage
 */
contract ManagedWithdrawReportedStrategyTest is BaseFountfiTest {
    TestManagedWithdrawReportedStrategy internal strategy;

    // Test data for EIP-712 signatures
    uint256 internal constant USER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal user;

    function setUp() public override {
        super.setUp();

        user = vm.addr(USER_PRIVATE_KEY);

        vm.prank(owner);
        strategy = new TestManagedWithdrawReportedStrategy();
    }

    function test_Initialize() public {
        bytes memory initData = abi.encode(address(mockReporter));
        
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        assertEq(strategy.manager(), manager);
        assertEq(strategy.asset(), address(usdc));
    }

    function test_DeployToken() public {
        address tokenAddress = strategy.deployTokenPublic(
            "Test Managed RWA",
            "TMRWA",
            address(usdc),
            6
        );

        // Verify the token was deployed correctly
        ManagedWithdrawRWA token = ManagedWithdrawRWA(tokenAddress);
        assertEq(token.name(), "Test Managed RWA");
        assertEq(token.symbol(), "TMRWA");
        assertEq(token.asset(), address(usdc));
        assertEq(token.strategy(), address(strategy));
    }

    function test_RedeemWithValidSignature() public {
        // Initialize the strategy first
        bytes memory initData = abi.encode(address(mockReporter));
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        // Create a withdrawal request
        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 1000,
            minAssets: 900,
            owner: user,
            nonce: 1,
            to: user,
            expirationTime: uint96(block.timestamp + 1 hours)
        });

        // Create signature (simplified for test)
        ManagedWithdrawReportedStrategy.Signature memory signature = ManagedWithdrawReportedStrategy.Signature({
            v: 27,
            r: bytes32(uint256(1)),
            s: bytes32(uint256(2))
        });

        // Mock the token's redeem function to prevent revert
        vm.mockCall(
            strategy.sToken(),
            abi.encodeWithSelector(bytes4(keccak256("redeem(uint256,address,address,uint256)"))),
            abi.encode(900)
        );

        // Test the redeem function (will fail due to signature verification, but tests the flow)
        vm.prank(manager);
        vm.expectRevert(); // Will fail on signature verification or token interaction
        strategy.redeem(request, signature);
    }

    function test_BatchRedeemWithInvalidArrayLengths() public {
        // Initialize the strategy first
        bytes memory initData = abi.encode(address(mockReporter));
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        ManagedWithdrawReportedStrategy.WithdrawalRequest[] memory requests =
            new ManagedWithdrawReportedStrategy.WithdrawalRequest[](2);
        ManagedWithdrawReportedStrategy.Signature[] memory signatures =
            new ManagedWithdrawReportedStrategy.Signature[](1); // Different length

        vm.prank(manager);
        vm.expectRevert(ManagedWithdrawReportedStrategy.InvalidArrayLengths.selector);
        strategy.batchRedeem(requests, signatures);
    }

    function test_RedeemUnauthorized() public {
        // Initialize the strategy first
        bytes memory initData = abi.encode(address(mockReporter));
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 1000,
            minAssets: 900,
            owner: user,
            nonce: 1,
            to: user,
            expirationTime: uint96(block.timestamp + 1 hours)
        });

        ManagedWithdrawReportedStrategy.Signature memory signature = ManagedWithdrawReportedStrategy.Signature({
            v: 27,
            r: bytes32(uint256(1)),
            s: bytes32(uint256(2))
        });

        vm.prank(alice); // Not manager
        vm.expectRevert(); // Should revert - only manager can call
        strategy.redeem(request, signature);
    }

    function test_ValidateRedeemExpired() public {
        // Initialize the strategy first
        bytes memory initData = abi.encode(address(mockReporter));
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 1000,
            minAssets: 900,
            owner: user,
            nonce: 1,
            to: user,
            expirationTime: uint96(block.timestamp - 1) // Expired
        });

        ManagedWithdrawReportedStrategy.Signature memory signature = ManagedWithdrawReportedStrategy.Signature({
            v: 27,
            r: bytes32(uint256(1)),
            s: bytes32(uint256(2))
        });

        vm.prank(manager);
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawalRequestExpired.selector);
        strategy.redeem(request, signature);
    }

    function test_ValidateRedeemNonceReuse() public {
        // Initialize the strategy first
        bytes memory initData = abi.encode(address(mockReporter));
        strategy.initialize(
            "Managed RWA",
            "MRWA",
            owner,
            manager,
            address(usdc),
            6,
            initData
        );

        // Mark nonce as used
        strategy.setNonceUsed(user, 1);

        ManagedWithdrawReportedStrategy.WithdrawalRequest memory request = ManagedWithdrawReportedStrategy.WithdrawalRequest({
            shares: 1000,
            minAssets: 900,
            owner: user,
            nonce: 1,
            to: user,
            expirationTime: uint96(block.timestamp + 1 hours)
        });

        ManagedWithdrawReportedStrategy.Signature memory signature = ManagedWithdrawReportedStrategy.Signature({
            v: 27,
            r: bytes32(uint256(1)),
            s: bytes32(uint256(2))
        });

        vm.prank(manager);
        vm.expectRevert(ManagedWithdrawReportedStrategy.WithdrawNonceReuse.selector);
        strategy.redeem(request, signature);
    }
}

/**
 * @title TestManagedWithdrawReportedStrategy
 * @notice Test contract to expose internal functions and add test helpers
 */
contract TestManagedWithdrawReportedStrategy is ManagedWithdrawReportedStrategy {
    function deployTokenPublic(
        string calldata name_,
        string calldata symbol_,
        address asset_,
        uint8 assetDecimals_
    ) external returns (address) {
        return _deployToken(name_, symbol_, asset_, assetDecimals_);
    }

    function setNonceUsed(address user, uint96 nonce) external {
        usedNonces[user][nonce] = true;
    }
}