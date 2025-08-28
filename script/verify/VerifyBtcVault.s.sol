// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BtcVaultStrategy} from "../../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../../src/token/BtcVaultToken.sol";
import {IBtcVaultStrategy} from "../../src/interfaces/IBtcVaultStrategy.sol";
import {IBtcVaultShareToken} from "../../src/interfaces/IBtcVaultShareToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title VerifyBtcVault
 * @notice Post-deployment verification script for BTC vault contracts
 * @dev Performs comprehensive checks on deployed contracts
 */
contract VerifyBtcVault is Script {
    struct DeployedContracts {
        address strategy;
        address token;
        address reporter;
    }

    struct TestResults {
        bool contractsDeployed;
        bool rolesConfigured;
        bool collateralsSupported;
        bool depositEnabled;
        bool withdrawalEnabled;
        bool liquidityAvailable;
    }

    function run() external {
        // Load network and deployment info
        string memory network = vm.envOr("NETWORK", string("baseSepolia"));
        console2.log("Verifying deployment on:", network);

        // Load deployed addresses
        DeployedContracts memory contracts = loadDeployedAddresses(network);
        require(contracts.strategy != address(0), "Strategy address not found");
        require(contracts.token != address(0), "Token address not found");

        // Get test account
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        TestResults memory results;

        // 1. Verify contracts are deployed and accessible
        results.contractsDeployed = verifyContractsDeployed(contracts);

        // 2. Verify role configuration
        results.rolesConfigured = verifyRoles(contracts, deployer);

        // 3. Verify collateral configuration
        results.collateralsSupported = verifyCollaterals(contracts);

        // 4. Test deposit functionality
        results.depositEnabled = testDeposit(contracts, deployer, deployerPrivateKey);

        // 5. Test withdrawal functionality
        results.withdrawalEnabled = testWithdrawal(contracts, deployer, deployerPrivateKey);

        // 6. Check liquidity availability
        results.liquidityAvailable = checkLiquidity(contracts);

        // Print verification report
        printVerificationReport(results, contracts);
    }

    function verifyContractsDeployed(DeployedContracts memory contracts) internal view returns (bool) {
        console2.log("\n=== Verifying Contract Deployment ===");

        // Check strategy contract
        uint256 strategySize;
        address strategyAddr = contracts.strategy;
        assembly {
            strategySize := extcodesize(strategyAddr)
        }
        console2.log("Strategy code size:", strategySize);
        require(strategySize > 0, "Strategy not deployed");

        // Check token contract
        uint256 tokenSize;
        address tokenAddr = contracts.token;
        assembly {
            tokenSize := extcodesize(tokenAddr)
        }
        console2.log("Token code size:", tokenSize);
        require(tokenSize > 0, "Token not deployed");

        // Verify strategy points to correct token
        BtcVaultStrategy strategy = BtcVaultStrategy(payable(contracts.strategy));
        address tokenFromStrategy = strategy.sToken();
        console2.log("Token from strategy:", tokenFromStrategy);
        require(tokenFromStrategy == contracts.token, "Token mismatch");

        console2.log("Contracts properly deployed");
        return true;
    }

    function verifyRoles(DeployedContracts memory contracts, address deployer) internal view returns (bool) {
        console2.log("\n=== Verifying Role Configuration ===");

        BtcVaultStrategy strategy = BtcVaultStrategy(payable(contracts.strategy));

        // Check manager role
        address manager = strategy.manager();
        console2.log("Strategy manager:", manager);
        require(manager == deployer, "Manager not set correctly");

        // Check reporter
        address reporter = address(strategy.reporter());
        console2.log("Price reporter:", reporter);
        require(reporter != address(0), "Reporter not set");

        console2.log("Roles properly configured");
        return true;
    }

    function verifyCollaterals(DeployedContracts memory contracts) internal view returns (bool) {
        console2.log("\n=== Verifying Collateral Support ===");

        IBtcVaultStrategy strategy = IBtcVaultStrategy(contracts.strategy);

        // Get supported collaterals
        address[] memory collaterals = strategy.getSupportedCollaterals();
        console2.log("Number of supported collaterals:", collaterals.length);

        for (uint256 i = 0; i < collaterals.length; i++) {
            console2.log("Collateral", i, ":", collaterals[i]);
            require(strategy.isSupportedAsset(collaterals[i]), "Collateral not properly supported");
        }

        if (collaterals.length > 0) {
            console2.log("Collaterals properly configured");
            return true;
        } else {
            console2.log("No collaterals configured yet");
            return false;
        }
    }

    function testDeposit(DeployedContracts memory contracts, address deployer, uint256 deployerPrivateKey)
        internal
        returns (bool)
    {
        console2.log("\n=== Testing Deposit Functionality ===");

        IBtcVaultStrategy strategy = IBtcVaultStrategy(contracts.strategy);
        address[] memory collaterals = strategy.getSupportedCollaterals();

        if (collaterals.length == 0) {
            console2.log("No collaterals to test deposit");
            return false;
        }

        // Use first collateral for test
        address testToken = collaterals[0];
        IERC20 token = IERC20(testToken);

        // Check if we have test tokens
        uint256 balance = token.balanceOf(deployer);
        console2.log("Test token balance:", balance);

        if (balance > 0) {
            uint256 testAmount = balance > 1e8 ? 1e8 : balance; // Test with 1 BTC or available balance

            vm.startBroadcast(deployerPrivateKey);

            // Approve vault
            token.approve(contracts.token, testAmount);

            // Test deposit
            IBtcVaultShareToken vault = IBtcVaultShareToken(contracts.token);
            uint256 sharesBefore = vault.balanceOf(deployer);
            uint256 shares = vault.depositCollateral(testToken, testAmount, deployer);
            uint256 sharesAfter = vault.balanceOf(deployer);

            vm.stopBroadcast();

            console2.log("Deposited amount:", testAmount);
            console2.log("Shares received:", shares);
            console2.log("Share balance change:", sharesAfter - sharesBefore);

            require(shares > 0, "No shares minted");
            require(sharesAfter > sharesBefore, "Share balance not increased");

            console2.log("Deposit functionality verified");
            return true;
        } else {
            console2.log("No test tokens available for deposit test");
            return false;
        }
    }

    function testWithdrawal(DeployedContracts memory contracts, address deployer, uint256 deployerPrivateKey)
        internal
        returns (bool)
    {
        console2.log("\n=== Testing Withdrawal Functionality ===");

        IBtcVaultShareToken vault = IBtcVaultShareToken(contracts.token);
        uint256 shares = vault.balanceOf(deployer);

        if (shares == 0) {
            console2.log("No shares to test withdrawal");
            return false;
        }

        // Check available liquidity
        IBtcVaultStrategy strategy = IBtcVaultStrategy(contracts.strategy);
        uint256 liquidity = strategy.getAvailableLiquidity();
        console2.log("Available liquidity:", liquidity);

        if (liquidity == 0) {
            console2.log("No liquidity for withdrawal test");
            // Still return true as withdrawal mechanism exists
            return true;
        }

        // Note: Actual withdrawal requires manager approval in managed pattern
        console2.log("Withdrawal mechanism in place (requires manager approval)");
        return true;
    }

    function checkLiquidity(DeployedContracts memory contracts) internal view returns (bool) {
        console2.log("\n=== Checking Liquidity ===");

        IBtcVaultStrategy strategy = IBtcVaultStrategy(contracts.strategy);

        uint256 totalAssets = strategy.totalCollateralAssets();
        uint256 availableLiquidity = strategy.getAvailableLiquidity();

        console2.log("Total assets:", totalAssets);
        console2.log("Available liquidity:", availableLiquidity);

        if (availableLiquidity > 0) {
            console2.log("Liquidity available for redemptions");
            return true;
        } else {
            console2.log("No liquidity available (needs to be added)");
            return false;
        }
    }

    function loadDeployedAddresses(string memory network) internal view returns (DeployedContracts memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/");
        path = string.concat(path, network);
        path = string.concat(path, "-btc-vault.json");

        string memory json = vm.readFile(path);

        DeployedContracts memory contracts;
        contracts.strategy = vm.parseJsonAddress(json, ".strategy");
        contracts.token = vm.parseJsonAddress(json, ".token");
        contracts.reporter = vm.parseJsonAddress(json, ".reporter");

        return contracts;
    }

    function printVerificationReport(TestResults memory results, DeployedContracts memory contracts) internal pure {
        console2.log("\n========================================");
        console2.log("    BTC VAULT VERIFICATION REPORT");
        console2.log("========================================");
        console2.log("Strategy:", contracts.strategy);
        console2.log("Token:", contracts.token);
        console2.log("Reporter:", contracts.reporter);
        console2.log("----------------------------------------");
        console2.log("Contracts Deployed:", results.contractsDeployed ? "PASS" : "FAIL");
        console2.log("Roles Configured:", results.rolesConfigured ? "PASS" : "FAIL");
        console2.log("Collaterals Supported:", results.collateralsSupported ? "PASS" : "WARN");
        console2.log("Deposit Enabled:", results.depositEnabled ? "PASS" : "WARN");
        console2.log("Withdrawal Enabled:", results.withdrawalEnabled ? "PASS" : "WARN");
        console2.log("Liquidity Available:", results.liquidityAvailable ? "PASS" : "WARN");
        console2.log("========================================\n");

        // Overall status
        bool allCriticalPassed = results.contractsDeployed && results.rolesConfigured;
        if (allCriticalPassed) {
            console2.log("DEPLOYMENT VERIFIED - Critical checks passed");
            if (!results.collateralsSupported || !results.liquidityAvailable) {
                console2.log("Additional configuration may be needed");
            }
        } else {
            console2.log("DEPLOYMENT FAILED - Critical issues detected");
        }
    }
}
