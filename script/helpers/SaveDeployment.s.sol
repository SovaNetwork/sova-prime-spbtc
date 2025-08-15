// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {NetworkConfig} from "../../src/lib/NetworkConfig.sol";

/**
 * @title SaveDeployment
 * @notice Script to save deployment information to JSON file
 * @dev Saves contract addresses and configuration for reference
 */
contract SaveDeployment is Script {
    struct DeploymentInfo {
        uint256 chainId;
        string networkName;
        address strategy;
        address token;
        address oracle;
        address registry;
        string version;
        uint256 timestamp;
        address deployer;
    }

    function run(
        address strategy,
        address token,
        address oracle
    ) external {
        uint256 chainId = block.chainid;
        string memory networkName = NetworkConfig.getNetworkName(chainId);
        
        DeploymentInfo memory info = DeploymentInfo({
            chainId: chainId,
            networkName: networkName,
            strategy: strategy,
            token: token,
            oracle: oracle,
            registry: address(0), // To be set if registry is deployed
            version: "1.0.0",
            timestamp: block.timestamp,
            deployer: msg.sender
        });
        
        // Save to JSON file
        _saveToJson(info);
        
        // Print summary
        _printSummary(info);
    }

    function _saveToJson(DeploymentInfo memory info) internal {
        string memory obj = "deployment";
        
        // Build JSON object
        vm.serializeUint(obj, "chainId", info.chainId);
        vm.serializeString(obj, "networkName", info.networkName);
        vm.serializeAddress(obj, "strategy", info.strategy);
        vm.serializeAddress(obj, "token", info.token);
        vm.serializeAddress(obj, "oracle", info.oracle);
        vm.serializeAddress(obj, "registry", info.registry);
        vm.serializeString(obj, "version", info.version);
        vm.serializeUint(obj, "timestamp", info.timestamp);
        string memory json = vm.serializeAddress(obj, "deployer", info.deployer);
        
        // Generate filename with network and timestamp
        string memory filename = string(abi.encodePacked(
            "deployment-",
            _toLower(info.networkName),
            "-",
            vm.toString(info.timestamp),
            ".json"
        ));
        
        // Write to file
        vm.writeJson(json, filename);
        
        console2.log("Deployment saved to:", filename);
    }

    function _printSummary(DeploymentInfo memory info) internal pure {
        console2.log("\n=== Deployment Saved ===");
        console2.log("Network:", info.networkName);
        console2.log("Chain ID:", info.chainId);
        console2.log("Version:", info.version);
        console2.log("\nContract Addresses:");
        console2.log("  Strategy:", info.strategy);
        console2.log("  Token:", info.token);
        console2.log("  Oracle:", info.oracle);
        if (info.registry != address(0)) {
            console2.log("  Registry:", info.registry);
        }
        console2.log("\nDeployer:", info.deployer);
        console2.log("Timestamp:", info.timestamp);
    }

    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);
        
        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            if (char >= 0x41 && char <= 0x5A) {
                // Convert uppercase to lowercase
                result[i] = bytes1(uint8(char) + 32);
            } else if (char == 0x20) {
                // Replace space with hyphen
                result[i] = 0x2D;
            } else {
                result[i] = char;
            }
        }
        
        return string(result);
    }
}