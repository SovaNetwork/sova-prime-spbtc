// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {NetworkConfig} from "../../src/lib/NetworkConfig.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title ValidateNetwork
 * @notice Script to validate network configuration before deployment
 * @dev Checks token addresses, oracle feeds, and network settings
 */
contract ValidateNetwork is Script {
    struct ValidationResult {
        bool isValid;
        string[] errors;
        string[] warnings;
    }

    function run() external {
        uint256 chainId = block.chainid;
        console2.log("\n=== Network Validation ===");
        console2.log("Chain ID:", chainId);

        ValidationResult memory result = validateNetwork(chainId);

        // Print results
        _printResults(result);

        // Fail if invalid
        if (!result.isValid) {
            revert("Network validation failed");
        }
    }

    function validateNetwork(uint256 chainId) public returns (ValidationResult memory result) {
        result.isValid = true;
        result.errors = new string[](10);
        result.warnings = new string[](10);
        uint256 errorCount = 0;
        uint256 warningCount = 0;

        // Check if network is supported
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            result.errors[errorCount++] = "Network not supported";
            result.isValid = false;
            return result;
        }

        // Get network configuration
        NetworkConfig.Network memory network = NetworkConfig.getNetworkConfig(chainId);
        NetworkConfig.CollateralConfig[] memory collaterals = NetworkConfig.getCollaterals(chainId);

        console2.log("Network Name:", network.name);
        console2.log("BTC Oracle:", network.btcOracle);

        // Validate oracle address
        if (network.btcOracle == address(0)) {
            result.errors[errorCount++] = "Oracle address is zero";
            result.isValid = false;
        } else {
            // Check if oracle is a contract
            uint256 oracleCodeSize;
            address oracleAddr = network.btcOracle;
            assembly {
                oracleCodeSize := extcodesize(oracleAddr)
            }
            if (oracleCodeSize == 0) {
                result.warnings[warningCount++] = "Oracle address has no code (might be valid for testnets)";
            }
        }

        // Validate collaterals
        console2.log("\nValidating Collaterals:");
        for (uint256 i = 0; i < collaterals.length; i++) {
            NetworkConfig.CollateralConfig memory collateral = collaterals[i];
            console2.log("  Checking", collateral.symbol, "at", collateral.tokenAddress);

            if (collateral.tokenAddress == address(0)) {
                console2.log("    Skipping - zero address");
                continue;
            }

            // Check if token contract exists
            uint256 tokenCodeSize;
            address tokenAddr = collateral.tokenAddress;
            assembly {
                tokenCodeSize := extcodesize(tokenAddr)
            }

            if (tokenCodeSize == 0) {
                string memory error = string(abi.encodePacked(collateral.symbol, " token has no code at address"));
                result.warnings[warningCount++] = error;
                console2.log("    WARNING: No code at address");
            } else {
                // Try to call basic ERC20 functions
                try IERC20(collateral.tokenAddress).totalSupply() returns (uint256 supply) {
                    console2.log("    Total Supply:", supply);

                    // Check decimals
                    try IERC20(collateral.tokenAddress).decimals() returns (uint8 decimals) {
                        if (decimals != collateral.decimals) {
                            string memory warning = string(abi.encodePacked(collateral.symbol, " decimals mismatch"));
                            result.warnings[warningCount++] = warning;
                            console2.log(
                                "    WARNING: Decimals mismatch - expected", collateral.decimals, "got", decimals
                            );
                        } else {
                            console2.log("    Decimals: OK");
                        }
                    } catch {
                        console2.log("    WARNING: Cannot read decimals");
                    }
                } catch {
                    string memory error = string(abi.encodePacked(collateral.symbol, " is not an ERC20 token"));
                    result.errors[errorCount++] = error;
                    result.isValid = false;
                    console2.log("    ERROR: Not an ERC20 token");
                }
            }
        }

        // Validate gas settings
        console2.log("\nGas Settings:");
        console2.log("  Max Fee:", network.maxFeePerGas);
        console2.log("  Max Priority Fee:", network.maxPriorityFeePerGas);

        if (network.maxFeePerGas == 0) {
            result.warnings[warningCount++] = "Max fee per gas is zero";
        }

        // Arrays are already sized correctly based on counts

        return result;
    }

    function _printResults(ValidationResult memory result) internal pure {
        console2.log("\n=== Validation Results ===");

        if (result.isValid) {
            console2.log("Status: PASSED");
        } else {
            console2.log("Status: FAILED");
        }

        if (result.errors.length > 0) {
            console2.log("\nErrors:");
            for (uint256 i = 0; i < result.errors.length; i++) {
                if (bytes(result.errors[i]).length > 0) {
                    console2.log("  -", result.errors[i]);
                }
            }
        }

        if (result.warnings.length > 0) {
            console2.log("\nWarnings:");
            for (uint256 i = 0; i < result.warnings.length; i++) {
                if (bytes(result.warnings[i]).length > 0) {
                    console2.log("  -", result.warnings[i]);
                }
            }
        }

        console2.log("\n==========================");
    }
}
