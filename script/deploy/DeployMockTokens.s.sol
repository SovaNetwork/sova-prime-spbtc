// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title DeployMockTokens
 * @notice Deployment script for mock BTC tokens (WBTC, cbBTC)
 * @dev Deploys mock tokens and mints initial supply to deployer
 */
contract DeployMockTokens is Script {
    struct DeploymentOutput {
        address wbtc;
        address cbbtc;
        address deployer;
        uint256 mintedAmount;
        uint256 deployedBlock;
        uint256 timestamp;
    }

    function run() external returns (address wbtc, address cbbtc) {
        // Determine network
        string memory network = vm.envOr("NETWORK", string("baseSepolia"));
        console2.log("Deploying Mock Tokens to network:", network);

        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        // Mint amount: 100 BTC worth (in 8 decimals)
        uint256 mintAmount = 100 * 10 ** 8; // 100 BTC
        console2.log("Mint amount per token:", mintAmount);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock WBTC
        console2.log("\n1. Deploying Mock WBTC...");
        MockERC20 wbtcToken = new MockERC20("Wrapped BTC", "WBTC", 8);
        wbtc = address(wbtcToken);
        console2.log("   Mock WBTC deployed at:", wbtc);

        // 2. Deploy Mock cbBTC
        console2.log("\n2. Deploying Mock cbBTC...");
        MockERC20 cbbtcToken = new MockERC20("Coinbase Wrapped BTC", "cbBTC", 8);
        cbbtc = address(cbbtcToken);
        console2.log("   Mock cbBTC deployed at:", cbbtc);

        // 3. Mint tokens to deployer
        console2.log("\n3. Minting tokens to deployer...");
        wbtcToken.mint(deployer, mintAmount);
        console2.log("   Minted WBTC:", mintAmount);

        cbbtcToken.mint(deployer, mintAmount);
        console2.log("   Minted cbBTC:", mintAmount);

        // 4. Verify balances
        console2.log("\n4. Verifying balances...");
        console2.log("   WBTC balance:", wbtcToken.balanceOf(deployer));
        console2.log("   cbBTC balance:", cbbtcToken.balanceOf(deployer));

        vm.stopBroadcast();

        // Save deployment output
        DeploymentOutput memory output = DeploymentOutput({
            wbtc: wbtc,
            cbbtc: cbbtc,
            deployer: deployer,
            mintedAmount: mintAmount,
            deployedBlock: block.number,
            timestamp: block.timestamp
        });

        saveDeploymentOutput(network, output);

        // Log deployment summary
        console2.log("\n=== Mock Tokens Deployment Summary ===");
        console2.log("Network:", network);
        console2.log("Mock WBTC:", wbtc);
        console2.log("Mock cbBTC:", cbbtc);
        console2.log("Deployer:", deployer);
        console2.log("Minted per token:", mintAmount, "(100 BTC)");
        console2.log("Block Number:", block.number);
        console2.log("=======================================\n");

        console2.log("IMPORTANT: Update deployment.config.json with these addresses:");
        console2.log("  wBTC:", wbtc);
        console2.log("  cbBTC:", cbbtc);

        // Verification instructions
        console2.log("\nRun verification with:");
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(wbtc),
                " src/mocks/MockERC20.sol:MockERC20 --chain ",
                network,
                " --constructor-args $(cast abi-encode \"constructor(string,string,uint8)\" \"Wrapped BTC\" \"WBTC\" 8)"
            )
        );
        console2.log(
            string.concat(
                "forge verify-contract ",
                vm.toString(cbbtc),
                " src/mocks/MockERC20.sol:MockERC20 --chain ",
                network,
                " --constructor-args $(cast abi-encode \"constructor(string,string,uint8)\" \"Coinbase Wrapped BTC\" \"cbBTC\" 8)"
            )
        );

        return (wbtc, cbbtc);
    }

    function saveDeploymentOutput(string memory network, DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/");
        path = string.concat(path, network);
        path = string.concat(path, "-mock-tokens.json");

        // Create JSON output
        string memory json = "deployment";
        vm.serializeAddress(json, "wbtc", output.wbtc);
        vm.serializeAddress(json, "cbbtc", output.cbbtc);
        vm.serializeAddress(json, "deployer", output.deployer);
        vm.serializeUint(json, "mintedAmount", output.mintedAmount);
        vm.serializeUint(json, "deployedBlock", output.deployedBlock);
        string memory finalJson = vm.serializeUint(json, "timestamp", output.timestamp);

        // Write to file
        vm.writeJson(finalJson, path);
        console2.log("Deployment output saved to:", path);
    }
}
