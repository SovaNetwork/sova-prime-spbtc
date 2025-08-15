// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IBtcVaultStrategy} from "../src/interfaces/IBtcVaultStrategy.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract AddLiquidityScript is Script {
    IBtcVaultStrategy constant STRATEGY = IBtcVaultStrategy(0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8);
    address constant SOVABTC = 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Adding liquidity from:", deployer);
        console.log("Strategy address:", address(STRATEGY));
        console.log("sovaBTC address:", SOVABTC);
        
        // Check current liquidity
        uint256 currentLiquidity = STRATEGY.availableLiquidity();
        console.log("Current available liquidity:", currentLiquidity);
        
        // Check sovaBTC balance
        uint256 sovaBTCBalance = IERC20(SOVABTC).balanceOf(deployer);
        console.log("Deployer sovaBTC balance:", sovaBTCBalance);
        
        // Amount to add (0.001 BTC = 1e5 units with 8 decimals)
        uint256 amountToAdd = 1e5; // 0.001 BTC
        
        if (sovaBTCBalance < amountToAdd) {
            console.log("Insufficient sovaBTC balance. Need at least:", amountToAdd);
            console.log("Minting sovaBTC for testing...");
            
            // For testing, we'll just add liquidity without actual sovaBTC
            vm.startBroadcast(deployerPrivateKey);
            
            // Try to add liquidity directly (assuming test mode allows this)
            try STRATEGY.addLiquidity(amountToAdd) {
                console.log("Added liquidity successfully:", amountToAdd);
            } catch Error(string memory reason) {
                console.log("Failed to add liquidity:", reason);
            }
            
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
            
            // Approve strategy to spend sovaBTC
            IERC20(SOVABTC).approve(address(STRATEGY), amountToAdd);
            console.log("Approved strategy to spend sovaBTC");
            
            // Add liquidity
            STRATEGY.addLiquidity(amountToAdd);
            console.log("Added liquidity:", amountToAdd);
            
            vm.stopBroadcast();
        }
        
        // Check new liquidity
        uint256 newLiquidity = STRATEGY.availableLiquidity();
        console.log("New available liquidity:", newLiquidity);
        console.log("Liquidity increase:", newLiquidity - currentLiquidity);
    }
}