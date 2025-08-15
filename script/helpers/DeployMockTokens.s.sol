// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract DeployMockTokens is Script {
    function run() external returns (address wbtc, address tbtc, address sovabtc) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying mock tokens...");

        // Deploy WBTC (8 decimals)
        MockERC20 wbtcToken = new MockERC20("Wrapped BTC", "WBTC", 8);
        wbtc = address(wbtcToken);
        console.log("Mock WBTC deployed at:", wbtc);

        // Deploy TBTC (18 decimals to test different decimals)
        MockERC20 tbtcToken = new MockERC20("tBTC", "TBTC", 18);
        tbtc = address(tbtcToken);
        console.log("Mock TBTC deployed at:", tbtc);

        // Deploy sovaBTC (8 decimals)
        MockERC20 sovabtcToken = new MockERC20("Sova BTC", "sovaBTC", 8);
        sovabtc = address(sovabtcToken);
        console.log("Mock sovaBTC deployed at:", sovabtc);

        // Mint some tokens for testing (10 BTC each)
        wbtcToken.mint(msg.sender, 10 * 10 ** 8);
        tbtcToken.mint(msg.sender, 10 * 10 ** 18);
        sovabtcToken.mint(msg.sender, 10 * 10 ** 8);

        console.log("Minted 10 BTC worth of each token to:", msg.sender);

        vm.stopBroadcast();

        console.log("\n=== Mock Tokens Deployed ===");
        console.log("WBTC:", wbtc);
        console.log("TBTC:", tbtc);
        console.log("sovaBTC:", sovabtc);

        return (wbtc, tbtc, sovabtc);
    }
}
