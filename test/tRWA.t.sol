// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title TRWATest
 * @notice Simple test to get something passing
 */
contract TRWATest is Test {
    // Test accounts
    address internal owner;
    address internal alice;
    
    // Key contracts
    MockERC20 public token;
    
    function setUp() public {
        // Setup accounts
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        
        vm.startPrank(owner);
        
        // Deploy token
        token = new MockERC20("USD Coin", "USDC", 6);
        
        // Mint some tokens to alice for testing
        token.mint(alice, 1_000_000 * 10**6);
        
        vm.stopPrank();
    }
    
    function test_TokenBasics() public {
        // Test token properties
        assertEq(token.name(), "USD Coin");
        assertEq(token.symbol(), "USDC");
        assertEq(token.decimals(), 6);
        
        // Test balance
        assertEq(token.balanceOf(alice), 1_000_000 * 10**6);
        
        // Test transfer
        vm.prank(alice);
        token.transfer(owner, 1000 * 10**6);
        
        assertEq(token.balanceOf(alice), 1_000_000 * 10**6 - 1000 * 10**6);
        assertEq(token.balanceOf(owner), 1000 * 10**6);
    }
}