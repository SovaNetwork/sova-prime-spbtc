// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {SovaBTCv1} from "../../src/token/SovaBTCv1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeploySovaBTCv1
 * @notice Deployment script for SovaBTCv1 upgradeable token
 * @dev Deploys implementation and proxy using UUPS pattern
 */
contract DeploySovaBTCv1 is Script {
    struct DeploymentOutput {
        address implementation;
        address proxy;
        address admin;
        uint256 deployedBlock;
        uint256 timestamp;
    }

    function run() external returns (address implementation, address proxy) {
        // Determine network
        string memory network = vm.envOr("NETWORK", string("baseSepolia"));
        console2.log("Deploying SovaBTCv1 to network:", network);

        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        // Get admin address (defaults to deployer if not set)
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        console2.log("Admin address:", admin);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation contract
        console2.log("\n1. Deploying SovaBTCv1 implementation...");
        SovaBTCv1 implementationContract = new SovaBTCv1();
        implementation = address(implementationContract);
        console2.log("   Implementation deployed at:", implementation);

        // 2. Prepare initialization data
        console2.log("\n2. Preparing initialization data...");
        bytes memory initData = abi.encodeWithSelector(
            SovaBTCv1.initialize.selector,
            admin
        );

        // 3. Deploy proxy
        console2.log("\n3. Deploying ERC1967 Proxy...");
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            implementation,
            initData
        );
        proxy = address(proxyContract);
        console2.log("   Proxy deployed at:", proxy);

        // 4. Verify deployment
        console2.log("\n4. Verifying deployment...");
        SovaBTCv1 token = SovaBTCv1(proxy);
        console2.log("   Token name:", token.name());
        console2.log("   Token symbol:", token.symbol());
        console2.log("   Token decimals:", token.decimals());
        console2.log("   Token version:", token.version());
        console2.log("   Token admin:", token.admin());
        console2.log("   Total supply:", token.totalSupply());

        vm.stopBroadcast();

        // Save deployment output
        DeploymentOutput memory output = DeploymentOutput({
            implementation: implementation,
            proxy: proxy,
            admin: admin,
            deployedBlock: block.number,
            timestamp: block.timestamp
        });

        saveDeploymentOutput(network, output);

        // Log deployment summary
        console2.log("\n=== SovaBTCv1 Deployment Summary ===");
        console2.log("Network:", network);
        console2.log("Implementation:", implementation);
        console2.log("Proxy (Token Address):", proxy);
        console2.log("Admin:", admin);
        console2.log("Block Number:", block.number);
        console2.log("Pattern: UUPS Upgradeable");
        console2.log("====================================\n");

        console2.log("IMPORTANT: Use the PROXY address as the sovaBTC address in deployment.config.json");
        console2.log("Proxy address to use:", proxy);

        // Verification instructions
        console2.log("\nRun verification with:");
        console2.log(string.concat("forge verify-contract ", vm.toString(implementation), " src/token/SovaBTCv1.sol:SovaBTCv1 --chain ", network));
        console2.log(string.concat("forge verify-contract ", vm.toString(proxy), " lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain ", network));

        return (implementation, proxy);
    }

    function saveDeploymentOutput(string memory network, DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/");
        path = string.concat(path, network);
        path = string.concat(path, "-sovabtcv1.json");

        // Create JSON output
        string memory json = "deployment";
        vm.serializeAddress(json, "implementation", output.implementation);
        vm.serializeAddress(json, "proxy", output.proxy);
        vm.serializeAddress(json, "admin", output.admin);
        vm.serializeUint(json, "deployedBlock", output.deployedBlock);
        string memory finalJson = vm.serializeUint(json, "timestamp", output.timestamp);

        // Write to file
        vm.writeJson(finalJson, path);
        console2.log("Deployment output saved to:", path);
    }
}