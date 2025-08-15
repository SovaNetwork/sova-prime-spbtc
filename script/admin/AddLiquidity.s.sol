// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IMockToken {
    function mint(address to, uint256 amount) external;
    function decimals() external view returns (uint8);
}

contract AddLiquidity is Script {
    address constant STRATEGY = 0x740907524EbD6A481a81cE76B5115A4cDDb80099;
    address constant SOVABTC = 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9;
    
    uint256 constant LIQUIDITY_AMOUNT = 10 * 1e8; // 10 sovaBTC (8 decimals)
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Adding sovaBTC liquidity to strategy");
        console2.log("Deployer:", deployer);
        console2.log("Strategy:", STRATEGY);
        console2.log("sovaBTC:", SOVABTC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check current balance
        uint256 currentBalance = IERC20(SOVABTC).balanceOf(STRATEGY);
        console2.log("Current strategy sovaBTC balance:", currentBalance);
        
        // Mint sovaBTC to deployer
        console2.log("Minting", LIQUIDITY_AMOUNT, "sovaBTC to deployer");
        IMockToken(SOVABTC).mint(deployer, LIQUIDITY_AMOUNT);
        
        // Check deployer balance
        uint256 deployerBalance = IERC20(SOVABTC).balanceOf(deployer);
        console2.log("Deployer sovaBTC balance after mint:", deployerBalance);
        
        // Transfer to strategy
        console2.log("Transferring sovaBTC to strategy");
        IERC20(SOVABTC).transfer(STRATEGY, LIQUIDITY_AMOUNT);
        
        // Verify final balance
        uint256 finalBalance = IERC20(SOVABTC).balanceOf(STRATEGY);
        console2.log("Final strategy sovaBTC balance:", finalBalance);
        console2.log("Liquidity added:", finalBalance - currentBalance);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Liquidity Successfully Added ===");
        console2.log("Strategy now has sufficient sovaBTC for redemptions");
    }
}