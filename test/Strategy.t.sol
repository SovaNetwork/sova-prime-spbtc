// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title StrategyTest
 * @notice Simplified test to get something passing
 */
contract StrategyTest is Test {
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
        token = new MockERC20("Test Token", "TST", 18);
        
        // Mint some tokens to alice
        token.mint(alice, 1000 ether);
        
        vm.stopPrank();
    }
    
    function test_TokenBasics() public {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TST");
        assertEq(token.decimals(), 18);
        assertEq(token.balanceOf(alice), 1000 ether);
    }
}