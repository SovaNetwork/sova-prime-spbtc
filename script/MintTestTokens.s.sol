// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MintTestTokensScript is Script {
    address constant SOVABTC = 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9;
    address constant WBTC = 0xe44b2870eFcd6Bb3C9305808012621f438e9636D;
    address constant TBTC = 0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Minting test tokens to:", deployer);

        // Amount to mint (0.1 BTC = 1e7 units with 8 decimals)
        uint256 amountToMint = 1e7; // 0.1 BTC

        vm.startBroadcast(deployerPrivateKey);

        // Mint sovaBTC
        MockERC20(SOVABTC).mint(deployer, amountToMint);
        console.log("Minted sovaBTC:", amountToMint);

        // Mint WBTC
        MockERC20(WBTC).mint(deployer, amountToMint);
        console.log("Minted WBTC:", amountToMint);

        // Mint TBTC
        MockERC20(TBTC).mint(deployer, amountToMint);
        console.log("Minted TBTC:", amountToMint);

        vm.stopBroadcast();

        // Check balances
        uint256 sovaBTCBalance = MockERC20(SOVABTC).balanceOf(deployer);
        uint256 wbtcBalance = MockERC20(WBTC).balanceOf(deployer);
        uint256 tbtcBalance = MockERC20(TBTC).balanceOf(deployer);

        console.log("Final balances:");
        console.log("- sovaBTC:", sovaBTCBalance);
        console.log("- WBTC:", wbtcBalance);
        console.log("- TBTC:", tbtcBalance);
    }
}
