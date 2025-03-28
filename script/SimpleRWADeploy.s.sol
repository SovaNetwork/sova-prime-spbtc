// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {SimpleRWA} from "../script/SimpleRWA.sol";

contract SimpleRWADeployScript is Script {
    function run() public {
        vm.startBroadcast();

        // Deploy RWA token with $1.00 initial underlying value per token
        SimpleRWA rwaToken = new SimpleRWA("Tokenized Real Estate Fund", "TREF", 1e18);
        console.log("SimpleRWA token deployed at:", address(rwaToken));

        // Mint some tokens
        rwaToken.mint(msg.sender, 1000e18);
        console.log("Minted 1000 tokens to deployer");

        vm.stopBroadcast();
    }
}