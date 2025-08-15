// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";

contract DeploymentAddresses is Script {
    struct Addresses {
        address roleManager;
        address registry;
        address strategy;
        address vault;
        address queue;
        address reporter;
        address conduit;
        address sovabtc;
    }

    mapping(uint256 => Addresses) public deployments;

    function saveDeployment(uint256 chainId, Addresses memory addrs) external {
        deployments[chainId] = addrs;

        // Check if file write should be skipped (for tests)
        bool skipWrite = false;
        try vm.envBool("SKIP_FILE_WRITE") returns (bool skip) {
            skipWrite = skip;
        } catch {
            // If env var doesn't exist, don't skip
        }

        if (!skipWrite) {
            _writeToFile(chainId, addrs);
        }
    }

    function getDeployment(uint256 chainId) external view returns (Addresses memory) {
        return deployments[chainId];
    }

    function _writeToFile(uint256 chainId, Addresses memory addrs) private {
        string memory deploymentDir = "deployments/";
        string memory chainName = _getChainName(chainId);
        string memory fileName = string.concat(deploymentDir, chainName, ".json");

        string memory json = "deploymentJson";
        vm.serializeAddress(json, "roleManager", addrs.roleManager);
        vm.serializeAddress(json, "registry", addrs.registry);
        vm.serializeAddress(json, "strategy", addrs.strategy);
        vm.serializeAddress(json, "vault", addrs.vault);
        vm.serializeAddress(json, "queue", addrs.queue);
        vm.serializeAddress(json, "reporter", addrs.reporter);
        vm.serializeAddress(json, "conduit", addrs.conduit);
        string memory output = vm.serializeAddress(json, "sovabtc", addrs.sovabtc);

        vm.writeFile(fileName, output);
    }

    function _getChainName(uint256 chainId) private pure returns (string memory) {
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 31337) return "local";
        return "unknown";
    }
}
