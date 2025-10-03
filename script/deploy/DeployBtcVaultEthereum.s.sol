// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BtcVaultStrategy} from "../../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../../src/reporter/PriceOracleReporter.sol";

/**
 * @title DeployBtcVaultEthereum
 * @notice Deployment script for BTC vault on Ethereum mainnet
 */
contract DeployBtcVaultEthereum is Script {
    // Ethereum Mainnet addresses
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    struct DeploymentOutput {
        address strategy;
        address token;
        address reporter;
        address roleManager;
        address sovaBTC;
        uint256 deployedBlock;
        uint256 timestamp;
    }

    function run() external returns (address strategy, address token) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);
        console2.log("Deploying BTC Vault to Ethereum Mainnet");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy RoleManager
        console2.log("\n1. Deploying RoleManager...");
        // Using the simple contract creation approach
        bytes memory roleManagerBytecode = type(RoleManager).creationCode;
        address roleManager;
        assembly {
            roleManager := create(0, add(roleManagerBytecode, 0x20), mload(roleManagerBytecode))
        }
        console2.log("   RoleManager deployed at:", roleManager);

        // 2. Deploy sovaBTC token
        console2.log("\n2. Deploying sovaBTC...");
        SovaBTCv1 sovaBtcImpl = new SovaBTCv1();
        bytes memory initData = abi.encodeWithSelector(SovaBTCv1.initialize.selector, deployer);
        ERC1967Proxy sovaBtcProxy = new ERC1967Proxy(address(sovaBtcImpl), initData);
        address sovaBTC = address(sovaBtcProxy);
        console2.log("   sovaBTC implementation:", address(sovaBtcImpl));
        console2.log("   sovaBTC proxy:", sovaBTC);

        // 3. Deploy PriceOracleReporter
        console2.log("\n3. Deploying PriceOracleReporter...");
        PriceOracleReporter reporter = new PriceOracleReporter(
            1e18, // Initial price per share (1:1)
            deployer, // Updater
            100, // Max deviation per time period (1%)
            86400 // Time period (24 hours)
        );
        console2.log("   PriceOracleReporter deployed at:", address(reporter));

        // 4. Deploy BtcVaultStrategy
        console2.log("\n4. Deploying BtcVaultStrategy...");
        BtcVaultStrategy btcStrategy = new BtcVaultStrategy();
        console2.log("   BtcVaultStrategy deployed at:", address(btcStrategy));

        // 5. Initialize strategy
        console2.log("\n5. Initializing BtcVaultStrategy...");
        bytes memory strategyInitData = abi.encode(address(reporter));
        btcStrategy.initialize(
            "Sova Prime BTC",
            "spBTC",
            roleManager,
            deployer, // manager
            sovaBTC,
            8, // decimals
            strategyInitData
        );
        console2.log("   Strategy initialized");

        // 6. Get auto-deployed token
        token = btcStrategy.sToken();
        console2.log("   BtcVaultToken auto-deployed at:", token);

        // 7. Add collateral support
        console2.log("\n6. Adding collateral support...");
        btcStrategy.addCollateral(WBTC);
        console2.log("   Added WBTC:", WBTC);
        btcStrategy.addCollateral(CBBTC);
        console2.log("   Added cbBTC:", CBBTC);

        vm.stopBroadcast();

        // Save deployment output
        DeploymentOutput memory output = DeploymentOutput({
            strategy: address(btcStrategy),
            token: token,
            reporter: address(reporter),
            roleManager: roleManager,
            sovaBTC: sovaBTC,
            deployedBlock: block.number,
            timestamp: block.timestamp
        });

        saveDeploymentOutput(output);

        // Log deployment summary
        console2.log("\n=== Ethereum BTC Vault Deployment Summary ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("RoleManager:", roleManager);
        console2.log("sovaBTC:", sovaBTC);
        console2.log("BtcVaultStrategy:", address(btcStrategy));
        console2.log("BtcVaultToken (spBTC):", token);
        console2.log("PriceOracleReporter:", address(reporter));
        console2.log("Collaterals: WBTC, cbBTC");
        console2.log("Block Number:", block.number);
        console2.log("============================================\n");

        return (address(btcStrategy), token);
    }

    function saveDeploymentOutput(DeploymentOutput memory output) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/ethereum-btc-vault.json");

        string memory json = "deployment";
        vm.serializeAddress(json, "strategy", output.strategy);
        vm.serializeAddress(json, "token", output.token);
        vm.serializeAddress(json, "reporter", output.reporter);
        vm.serializeAddress(json, "roleManager", output.roleManager);
        vm.serializeAddress(json, "sovaBTC", output.sovaBTC);
        vm.serializeUint(json, "deployedBlock", output.deployedBlock);
        string memory finalJson = vm.serializeUint(json, "timestamp", output.timestamp);

        vm.writeJson(finalJson, path);
        console2.log("Deployment output saved to:", path);
    }
}

// Import these for deployment
import {RoleManager} from "../../src/auth/RoleManager.sol";
import {SovaBTCv1} from "../../src/token/SovaBTCv1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
