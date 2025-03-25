// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {tRWA} from "../src/tRWA.sol";
import {NavOracle} from "../src/NavOracle.sol";
import {tRWAFactory} from "../src/tRWAFactory.sol";

contract tRWATest is Test {
    tRWA public token;
    NavOracle public oracle;
    tRWAFactory public factory;
    
    address public user1 = address(2);
    address public user2 = address(3);
    
    uint256 public initialUnderlying = 1e18; // $1.00 per token

    function setUp() public {
        // Deploy contracts
        oracle = new NavOracle();
        factory = new tRWAFactory(address(oracle));
        
        // Deploy a test token through the factory
        address tokenAddress = factory.deployToken("Tokenized Real Estate Fund", "TREF", initialUnderlying);
        token = tRWA(tokenAddress);
        
        // Mint some tokens to users for testing
        token.mint(user1, 1000e18);
        token.mint(user2, 500e18);
    }

    function test_InitialState() public {
        // Check initial token state
        assertEq(token.name(), "Tokenized Real Estate Fund");
        assertEq(token.symbol(), "TREF");
        assertEq(token.underlyingPerToken(), initialUnderlying);
        assertEq(token.oracle(), address(oracle));
        assertEq(token.admin(), address(this));
        
        // Check initial balances
        assertEq(token.balanceOf(user1), 1000e18);
        assertEq(token.balanceOf(user2), 500e18);
        assertEq(token.totalSupply(), 1500e18);
    }

    function test_UnderlyingValueUpdate() public {
        uint256 newValue = 1.05e18; // $1.05 per token
        
        // Update underlying value through the oracle
        oracle.updateUnderlyingValue(address(token), newValue);
        
        // Check if underlying value was updated
        assertEq(token.underlyingPerToken(), newValue);
        
        // Check USD value calculation
        assertEq(token.getUsdValue(1000e18), 1050e18); // $1,050 for 1000 shares
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
        oracle.updateUnderlyingValue(address(token), newValue);
        vm.stopPrank();
    }

    function test_TokenMintAndBurn() public {
        // Mint new tokens
        token.mint(user1, 500e18);
        assertEq(token.balanceOf(user1), 1500e18);
        assertEq(token.totalSupply(), 2000e18);
        
        // Burn tokens
        token.burn(user1, 300e18);
        assertEq(token.balanceOf(user1), 1200e18);
        assertEq(token.totalSupply(), 1700e18);
    }

    function test_UnauthorizedMintAndBurn() public {
        vm.startPrank(user1);
        
        // Try to mint tokens (should fail)
        vm.expectRevert();
        token.mint(user1, 500e18);
        
        // Try to burn tokens (should fail)
        vm.expectRevert();
        token.burn(user1, 100e18);
        
        vm.stopPrank();
    }

    function test_AdminUpdateOracle() public {
        address newOracle = address(4);
        
        token.updateOracle(newOracle);
        
        assertEq(token.oracle(), newOracle);
    }

    function test_AdminUpdateAdmin() public {
        address newAdmin = address(5);
        
        token.updateAdmin(newAdmin);
        
        assertEq(token.admin(), newAdmin);
    }

    function test_UnauthorizedAdminFunctions() public {
        address newOracle = address(4);
        address newAdmin = address(5);
        
        vm.startPrank(user1);
        
        // Try to update oracle (should fail)
        vm.expectRevert();
        token.updateOracle(newOracle);
        
        // Try to update admin (should fail)
        vm.expectRevert();
        token.updateAdmin(newAdmin);
        
        vm.stopPrank();
    }

    function testFuzz_UnderlyingValueCalculation(uint256 shares, uint256 underlying) public {
        // Bound inputs to reasonable ranges to avoid overflows
        shares = bound(shares, 1, 1e24);
        underlying = bound(underlying, 1e6, 1e20);
        
        oracle.updateUnderlyingValue(address(token), underlying);
        
        uint256 expectedUsdValue = (shares * underlying) / 1e18;
        assertEq(token.getUsdValue(shares), expectedUsdValue);
    }
}