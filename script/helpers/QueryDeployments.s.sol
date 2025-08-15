// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DeploymentRegistry} from "../../src/DeploymentRegistry.sol";
import {NetworkConfig} from "../../src/lib/NetworkConfig.sol";

/**
 * @title QueryDeployments
 * @notice Script to query and display deployment information from the registry
 * @dev Can query by network, deployment ID, or list all deployments
 */
contract QueryDeployments is Script {
    function run() external view {
        // Get registry address from environment or config
        address registryAddress = _getRegistryAddress();

        if (registryAddress == address(0)) {
            console2.log("No deployment registry configured");
            return;
        }

        DeploymentRegistry registry = DeploymentRegistry(registryAddress);

        // Get current network
        uint256 currentChainId = block.chainid;
        string memory networkName = _getNetworkName(currentChainId);

        console2.log("\n=== Deployment Query ===");
        console2.log("Registry Address:", registryAddress);
        console2.log("Current Network:", networkName);
        console2.log("Chain ID:", currentChainId);

        // Query deployments for current network
        _queryNetworkDeployments(registry, currentChainId);

        // Query all active deployments
        _queryAllActiveDeployments(registry);
    }

    function queryByNetwork(address registryAddress, uint256 chainId) external view {
        DeploymentRegistry registry = DeploymentRegistry(registryAddress);
        _queryNetworkDeployments(registry, chainId);
    }

    function queryById(address registryAddress, uint256 deploymentId) external view {
        DeploymentRegistry registry = DeploymentRegistry(registryAddress);
        _queryDeploymentById(registry, deploymentId);
    }

    function _queryNetworkDeployments(DeploymentRegistry registry, uint256 chainId) internal view {
        console2.log("\n--- Network Deployments ---");

        // Get network info
        DeploymentRegistry.NetworkInfo memory info = registry.getNetworkInfo(chainId);

        if (info.totalDeployments == 0) {
            console2.log("No deployments found for this network");
            return;
        }

        console2.log("Network:", info.name);
        console2.log("Total Deployments:", info.totalDeployments);
        console2.log("Active Deployment ID:", info.activeDeployment);

        // Get all deployment IDs for this network
        uint256[] memory deploymentIds = registry.getNetworkDeployments(chainId);

        console2.log("\nDeployment History:");
        for (uint256 i = 0; i < deploymentIds.length; i++) {
            DeploymentRegistry.Deployment memory deployment = registry.getDeployment(deploymentIds[i]);

            console2.log("\n  Deployment #", deploymentIds[i]);
            console2.log("    Version:", deployment.version);
            console2.log("    Strategy:", deployment.strategyAddress);
            console2.log("    Token:", deployment.tokenAddress);
            console2.log("    Oracle:", deployment.oracleAddress);
            console2.log("    Timestamp:", deployment.timestamp);
            console2.log("    Active:", deployment.isActive ? "Yes" : "No");
        }
    }

    function _queryAllActiveDeployments(DeploymentRegistry registry) internal view {
        console2.log("\n--- All Active Deployments ---");

        DeploymentRegistry.Deployment[] memory activeDeployments = registry.getAllActiveDeployments();

        if (activeDeployments.length == 0) {
            console2.log("No active deployments found");
            return;
        }

        console2.log("Total Active:", activeDeployments.length);

        for (uint256 i = 0; i < activeDeployments.length; i++) {
            DeploymentRegistry.Deployment memory deployment = activeDeployments[i];
            string memory networkName = _getNetworkName(deployment.chainId);

            console2.log("\n  Network:", networkName);
            console2.log("    Chain ID:", deployment.chainId);
            console2.log("    Version:", deployment.version);
            console2.log("    Strategy:", deployment.strategyAddress);
            console2.log("    Token:", deployment.tokenAddress);
            console2.log("    Oracle:", deployment.oracleAddress);
        }
    }

    function _queryDeploymentById(DeploymentRegistry registry, uint256 deploymentId) internal view {
        console2.log("\n--- Deployment Details ---");
        console2.log("Deployment ID:", deploymentId);

        try registry.getDeployment(deploymentId) returns (DeploymentRegistry.Deployment memory deployment) {
            string memory networkName = _getNetworkName(deployment.chainId);

            console2.log("Network:", networkName);
            console2.log("Chain ID:", deployment.chainId);
            console2.log("Version:", deployment.version);
            console2.log("Strategy:", deployment.strategyAddress);
            console2.log("Token:", deployment.tokenAddress);
            console2.log("Oracle:", deployment.oracleAddress);
            console2.log("Timestamp:", deployment.timestamp);
            console2.log("Active:", deployment.isActive ? "Yes" : "No");
        } catch {
            console2.log("Deployment not found");
        }
    }

    function _getRegistryAddress() internal view returns (address) {
        // Try to get from environment variable
        try vm.envAddress("DEPLOYMENT_REGISTRY") returns (address addr) {
            return addr;
        } catch {
            // Return zero if not configured
            return address(0);
        }
    }

    function _getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (NetworkConfig.isNetworkSupported(chainId)) {
            return NetworkConfig.getNetworkName(chainId);
        } else {
            return "Unknown Network";
        }
    }
}
