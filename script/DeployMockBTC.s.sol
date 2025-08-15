// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../src/test/MockBTC.sol";

contract DeployMockBTC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying MockBTC with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mock BTC token
        MockBTC mockBTC = new MockBTC("Mock Bitcoin", "mBTC");
        
        console.log("MockBTC deployed at:", address(mockBTC));
        console.log("Name:", mockBTC.name());
        console.log("Symbol:", mockBTC.symbol());
        console.log("Decimals:", mockBTC.decimals());
        console.log("Initial supply to deployer: 1000 mBTC");
        
        // Test mint function
        console.log("\nTesting public mint function...");
        mockBTC.mint(1 * 10**8); // Mint 1 BTC
        console.log("Successfully minted 1 mBTC");
        
        // Test faucet function
        console.log("\nTesting faucet function...");
        mockBTC.faucet(); // Get 1 BTC from faucet
        console.log("Successfully got 1 mBTC from faucet");
        
        uint256 balance = mockBTC.balanceOf(deployer);
        console.log("\nFinal deployer balance:", balance / 10**8, "mBTC");
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("MockBTC address:", address(mockBTC));
        console.log("\nTo add this token as supported collateral, run:");
        console.log("cast send", "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8"); // Strategy address
        console.log("  \"addCollateral(address,uint8)\"");
        console.log(" ", address(mockBTC), "8");
        console.log("  --private-key $PRIVATE_KEY");
        console.log("  --rpc-url base-sepolia");
    }
}