// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleRWA} from "../script/SimpleRWA.sol";

contract SimpleRWATest is Test {
    SimpleRWA public token;

    address public user1 = address(2);
    address public user2 = address(3);

    uint256 public initialUnderlying = 1e18; // $1.00 per token

    function setUp() public {
        // Deploy token
        token = new SimpleRWA("Tokenized Real Estate Fund", "TREF", initialUnderlying);

        // Mint initial tokens
        token.mint(user1, 1000e18);
        token.mint(user2, 500e18);
    }

    function test_InitialState() public view {
        assertEq(token.name(), "Tokenized Real Estate Fund");
        assertEq(token.symbol(), "TREF");
        assertEq(token.underlyingPerToken(), initialUnderlying);
        assertEq(token.owner(), address(this));

        // Check balances
        assertEq(token.balanceOf(user1), 1000e18);
        assertEq(token.balanceOf(user2), 500e18);
        assertEq(token.totalSupply(), 1500e18);
    }

    function test_UnderlyingValueUpdate() public {
        uint256 newValue = 1.05e18; // $1.05 per token

        // Update underlying value
        token.updateUnderlyingValue(newValue);

        // Check value updated
        assertEq(token.underlyingPerToken(), newValue);

        // Check USD values
        assertEq(token.getUsdValue(1000e18), 1050e18); // $1,050 for 1000 shares
    }

    function test_Transfer() public {
        // User1 transfers to User2
        vm.startPrank(user1);
        token.transfer(user2, 100e18);
        vm.stopPrank();

        // Check balances
        assertEq(token.balanceOf(user1), 900e18);
        assertEq(token.balanceOf(user2), 600e18);
    }

    function test_TransferFrom() public {
        // User1 approves this contract to spend tokens
        vm.startPrank(user1);
        token.approve(address(this), 200e18);
        vm.stopPrank();

        // Contract transfers from User1 to User2
        token.transferFrom(user1, user2, 150e18);

        // Check balances
        assertEq(token.balanceOf(user1), 850e18);
        assertEq(token.balanceOf(user2), 650e18);
        assertEq(token.allowance(user1, address(this)), 50e18);
    }

    function test_MintAndBurn() public {
        // Mint more tokens to User1
        token.deposit(500e18, user1);
        assertEq(token.balanceOf(user1), 1500e18);
        assertEq(token.totalSupply(), 2000e18);

        // Burn tokens from User2
        token.redeem(200e18, address(this), user2);
        assertEq(token.balanceOf(user2), 300e18);
        assertEq(token.totalSupply(), 1800e18);
    }

    function test_UnauthorizedOwnerFunctions() public {
        vm.startPrank(user1);

        // Try to mint (should fail)
        vm.expectRevert("Not authorized");
        token.deposit(100e18, user1);

        // Try to burn (should fail)
        vm.expectRevert("Not authorized");
        token.redeem(100e18, user1, user2);

        // Try to update underlying value (should fail)
        vm.expectRevert("Not authorized");
        token.updateUnderlyingValue(2e18);

        vm.stopPrank();
    }

    function testFuzz_UnderlyingValueCalculation(uint256 shares, uint256 underlying) public {
        // Bound inputs to reasonable ranges
        shares = bound(shares, 1, 1e24);
        underlying = bound(underlying, 1e6, 1e20);

        // Update underlying value
        token.updateUnderlyingValue(underlying);

        // Check calculation
        uint256 expectedValue = (shares * underlying) / 1e18;
        assertEq(token.getUsdValue(shares), expectedValue);
    }
}