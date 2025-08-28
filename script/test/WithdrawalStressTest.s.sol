// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IBtcVaultStrategy} from "src/interfaces/IBtcVaultStrategy.sol";
import {IBtcVaultShareToken} from "src/interfaces/IBtcVaultShareToken.sol";

contract WithdrawalStressTestScript is Script {
    // Deployed contract addresses on Base Sepolia
    address constant BTC_VAULT_STRATEGY = 0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8;
    address constant BTC_VAULT_TOKEN = 0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a;
    address constant SOVABTC_TOKEN = 0x9901Bdc36a2fD60aF17ca28c960e1FF2f968e426;
    address constant WBTC_TOKEN = 0xe44b2870eFcd6Bb3C9305808012621f438e9636D;

    // Test parameters
    uint256 constant DEPOSIT_AMOUNT = 0.1 ether; // 0.1 BTC worth per user
    uint256 constant WITHDRAWAL_BATCH_SIZE = 10;

    struct WithdrawalTestResult {
        uint256 totalWithdrawalsRequested;
        uint256 successfulRequests;
        uint256 failedRequests;
        uint256 totalWithdrawalsApproved;
        uint256 successfulApprovals;
        uint256 failedApprovals;
        uint256 totalWithdrawalsCompleted;
        uint256 successfulCompletions;
        uint256 failedCompletions;
        uint256 totalGasUsed;
        uint256 avgGasPerOperation;
        uint256 totalLiquidityUsed;
    }

    function run() external {
        console2.log("==== BTC Vault Withdrawal Stress Test Starting ====");
        console2.log("Strategy:", BTC_VAULT_STRATEGY);
        console2.log("Token:", BTC_VAULT_TOKEN);
        console2.log("");

        // Setup test environment
        setupTestEnvironment();

        // Run withdrawal stress tests
        WithdrawalTestResult memory batchTest = runBatchWithdrawalTest();
        reportWithdrawalResults("Batch Withdrawal Test", batchTest);

        WithdrawalTestResult memory concurrentTest = runConcurrentWithdrawalTest();
        reportWithdrawalResults("Concurrent Withdrawal Test", concurrentTest);

        WithdrawalTestResult memory liquidityTest = runLiquidityStressTest();
        reportWithdrawalResults("Liquidity Stress Test", liquidityTest);

        // Generate final report
        generateWithdrawalComparisonReport(batchTest, concurrentTest, liquidityTest);
    }

    function setupTestEnvironment() internal {
        console2.log("Setting up test environment...");

        // Check current liquidity
        IBtcVaultStrategy strategy = IBtcVaultStrategy(BTC_VAULT_STRATEGY);
        uint256 availableLiquidity = strategy.availableLiquidity();
        console2.log("Current Available Liquidity:", availableLiquidity);

        // Add more liquidity if needed
        if (availableLiquidity < 10 ether) {
            console2.log("Adding test liquidity...");
            vm.startPrank(vm.addr(1)); // Use a test address as manager

            // Note: Manager needs to be funded with sovaBTC before running this script
            // Assuming manager already has sovaBTC tokens

            IERC20(SOVABTC_TOKEN).approve(BTC_VAULT_STRATEGY, type(uint256).max);
            strategy.addLiquidity(50 ether);

            vm.stopPrank();
            console2.log("Added 50 sovaBTC liquidity");
        }

        console2.log("");
    }

    function runBatchWithdrawalTest() internal returns (WithdrawalTestResult memory result) {
        console2.log("Running Batch Withdrawal Test...");
        console2.log("Batch Size:", WITHDRAWAL_BATCH_SIZE);

        IBtcVaultStrategy strategy = IBtcVaultStrategy(BTC_VAULT_STRATEGY);
        IBtcVaultShareToken token = IBtcVaultShareToken(BTC_VAULT_TOKEN);

        // Create and fund test users
        address[] memory users = new address[](WITHDRAWAL_BATCH_SIZE);
        for (uint256 i = 0; i < WITHDRAWAL_BATCH_SIZE; i++) {
            users[i] = address(uint160(0x2000000 + i));

            // Fund user with collateral and deposit
            fundUserAndDeposit(users[i], DEPOSIT_AMOUNT);
        }

        // Request withdrawals for all users
        console2.log("Requesting batch withdrawals...");
        for (uint256 i = 0; i < users.length; i++) {
            uint256 shares = token.balanceOf(users[i]);

            if (shares > 0) {
                vm.startPrank(users[i]);

                uint256 gasBefore = gasleft();

                try token.redeem(shares, users[i], users[i]) returns (uint256 assets) {
                    result.successfulRequests++;
                    result.totalLiquidityUsed += assets;

                    uint256 gasUsed = gasBefore - gasleft();
                    result.totalGasUsed += gasUsed;
                } catch {
                    result.failedRequests++;
                }

                vm.stopPrank();
                result.totalWithdrawalsRequested++;
            }
        }

        // Note: Withdrawal approval has been refactored in the new architecture
        // Commenting out approval processing
        /*
        // Process approvals (as manager)
        console2.log("Processing withdrawal approvals...");
        vm.startPrank(vm.addr(1)); // Manager address
        
        for (uint256 i = 0; i < users.length; i++) {
            uint256 gasBefore = gasleft();
            
            try strategy.approveWithdrawal(users[i], token.balanceOf(users[i])) {
                result.successfulApprovals++;
                
                uint256 gasUsed = gasBefore - gasleft();
                result.totalGasUsed += gasUsed;
            } catch {
                result.failedApprovals++;
            }
            
            result.totalWithdrawalsApproved++;
        }
        
        vm.stopPrank();
        */

        // Note: Withdrawal completion has been refactored
        // Commenting out completion processing
        /*
        // Complete withdrawals
        console2.log("Completing withdrawals...");
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            
            uint256 gasBefore = gasleft();
            
            try token.completeWithdrawal() returns (uint256 assets) {
                result.successfulCompletions++;
                
                uint256 gasUsed = gasBefore - gasleft();
                result.totalGasUsed += gasUsed;
            } catch {
                result.failedCompletions++;
            }
            
            vm.stopPrank();
            result.totalWithdrawalsCompleted++;
        }
        */

        if (result.totalWithdrawalsRequested + result.totalWithdrawalsApproved + result.totalWithdrawalsCompleted > 0) {
            result.avgGasPerOperation = result.totalGasUsed
                / (result.totalWithdrawalsRequested + result.totalWithdrawalsApproved + result.totalWithdrawalsCompleted);
        }

        return result;
    }

    function runConcurrentWithdrawalTest() internal returns (WithdrawalTestResult memory result) {
        console2.log("Running Concurrent Withdrawal Test...");
        console2.log("Concurrent Users: 20");

        IBtcVaultStrategy strategy = IBtcVaultStrategy(BTC_VAULT_STRATEGY);
        IBtcVaultShareToken token = IBtcVaultShareToken(BTC_VAULT_TOKEN);

        uint256 concurrentUsers = 20;
        address[] memory users = new address[](concurrentUsers);

        // Setup users with deposits
        for (uint256 i = 0; i < concurrentUsers; i++) {
            users[i] = address(uint160(0x3000000 + i));
            fundUserAndDeposit(users[i], DEPOSIT_AMOUNT / 2);
        }

        // Simulate concurrent withdrawal requests
        console2.log("Simulating concurrent withdrawal requests...");

        for (uint256 i = 0; i < users.length; i++) {
            uint256 shares = token.balanceOf(users[i]);

            vm.startPrank(users[i]);

            uint256 gasBefore = gasleft();

            try token.redeem(shares, users[i], users[i]) returns (uint256 assets) {
                result.successfulRequests++;
                result.totalLiquidityUsed += assets;

                uint256 gasUsed = gasBefore - gasleft();
                result.totalGasUsed += gasUsed;
            } catch {
                result.failedRequests++;
            }

            vm.stopPrank();
            result.totalWithdrawalsRequested++;
        }

        // Note: Withdrawal approval has been refactored
        // Commenting out approval processing
        /*
        // Process all approvals at once
        console2.log("Processing concurrent approvals...");
        vm.startPrank(vm.addr(1)); // Manager
        
        for (uint256 i = 0; i < users.length; i++) {
            try strategy.approveWithdrawal(users[i], token.balanceOf(users[i])) {
                result.successfulApprovals++;
            } catch {
                result.failedApprovals++;
            }
            result.totalWithdrawalsApproved++;
        }
        
        vm.stopPrank();
        */

        // Note: Withdrawal completion has been refactored
        // Commenting out completion processing
        /*
        // Complete all withdrawals simultaneously
        console2.log("Completing concurrent withdrawals...");
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            
            try token.completeWithdrawal() returns (uint256) {
                result.successfulCompletions++;
            } catch {
                result.failedCompletions++;
            }
            
            vm.stopPrank();
            result.totalWithdrawalsCompleted++;
        }
        */

        if (result.totalWithdrawalsRequested + result.totalWithdrawalsApproved + result.totalWithdrawalsCompleted > 0) {
            result.avgGasPerOperation = result.totalGasUsed
                / (result.totalWithdrawalsRequested + result.totalWithdrawalsApproved + result.totalWithdrawalsCompleted);
        }

        return result;
    }

    function runLiquidityStressTest() internal returns (WithdrawalTestResult memory result) {
        console2.log("Running Liquidity Stress Test...");
        console2.log("Testing withdrawal capacity limits...");

        IBtcVaultStrategy strategy = IBtcVaultStrategy(BTC_VAULT_STRATEGY);
        IBtcVaultShareToken token = IBtcVaultShareToken(BTC_VAULT_TOKEN);

        // Get current liquidity
        uint256 availableLiquidity = strategy.availableLiquidity();
        console2.log("Available Liquidity:", availableLiquidity);

        // Create users requesting more than available liquidity
        uint256 userCount = 5;
        address[] memory users = new address[](userCount);
        uint256 amountPerUser = (availableLiquidity / userCount) + 0.1 ether;

        for (uint256 i = 0; i < userCount; i++) {
            users[i] = address(uint160(0x4000000 + i));
            fundUserAndDeposit(users[i], amountPerUser);
        }

        // Request withdrawals exceeding liquidity
        console2.log("Requesting withdrawals exceeding liquidity...");

        for (uint256 i = 0; i < users.length; i++) {
            uint256 shares = token.balanceOf(users[i]);

            vm.startPrank(users[i]);

            try token.redeem(shares, users[i], users[i]) returns (uint256 assets) {
                result.successfulRequests++;
                result.totalLiquidityUsed += assets;
            } catch {
                result.failedRequests++;
            }

            vm.stopPrank();
            result.totalWithdrawalsRequested++;
        }

        // Try to approve all withdrawals
        // Note: Withdrawal approval has been refactored
        // Commenting out approval processing
        /*
        console2.log("Attempting to approve all withdrawals...");
        vm.startPrank(vm.addr(1)); // Manager
        
        for (uint256 i = 0; i < users.length; i++) {
            try strategy.approveWithdrawal(users[i], token.balanceOf(users[i])) {
                result.successfulApprovals++;
            } catch {
                result.failedApprovals++;
                console2.log("  Approval failed for user", i, "(expected due to liquidity limit)");
            }
            result.totalWithdrawalsApproved++;
        }
        
        vm.stopPrank();
        */

        // Note: Withdrawal completion has been refactored
        // Commenting out completion processing
        /*
        // Complete successful withdrawals
        console2.log("Completing approved withdrawals...");
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            
            try token.completeWithdrawal() returns (uint256) {
                result.successfulCompletions++;
            } catch {
                result.failedCompletions++;
            }
            
            vm.stopPrank();
            result.totalWithdrawalsCompleted++;
        }
        */

        return result;
    }

    function fundUserAndDeposit(address user, uint256 amount) internal {
        IBtcVaultShareToken vault = IBtcVaultShareToken(BTC_VAULT_TOKEN);

        // Note: User needs to be funded with WBTC before running this script
        // Assuming user already has WBTC tokens

        vm.startPrank(user);
        IERC20(WBTC_TOKEN).approve(BTC_VAULT_TOKEN, type(uint256).max);
        vault.depositCollateral(WBTC_TOKEN, amount, user);
        vm.stopPrank();
    }

    function reportWithdrawalResults(string memory testName, WithdrawalTestResult memory result) internal pure {
        console2.log("");
        console2.log("====", testName, "Results ====");
        console2.log("Withdrawal Requests:");
        console2.log("  Total:", result.totalWithdrawalsRequested);
        console2.log("  Successful:", result.successfulRequests);
        console2.log("  Failed:", result.failedRequests);

        console2.log("Withdrawal Approvals:");
        console2.log("  Total:", result.totalWithdrawalsApproved);
        console2.log("  Successful:", result.successfulApprovals);
        console2.log("  Failed:", result.failedApprovals);

        console2.log("Withdrawal Completions:");
        console2.log("  Total:", result.totalWithdrawalsCompleted);
        console2.log("  Successful:", result.successfulCompletions);
        console2.log("  Failed:", result.failedCompletions);

        console2.log("Performance Metrics:");
        console2.log("  Total Gas Used:", result.totalGasUsed);
        console2.log("  Avg Gas per Operation:", result.avgGasPerOperation);
        console2.log("  Total Liquidity Used:", result.totalLiquidityUsed);
        console2.log("");
    }

    function generateWithdrawalComparisonReport(
        WithdrawalTestResult memory batch,
        WithdrawalTestResult memory concurrent,
        WithdrawalTestResult memory liquidity
    ) internal pure {
        console2.log("==== Withdrawal Stress Test Comparison ====");
        console2.log("");

        console2.log("Request Success Rates:");
        if (batch.totalWithdrawalsRequested > 0) {
            console2.log("  Batch Test:", (batch.successfulRequests * 100) / batch.totalWithdrawalsRequested, "%");
        }
        if (concurrent.totalWithdrawalsRequested > 0) {
            console2.log(
                "  Concurrent Test:", (concurrent.successfulRequests * 100) / concurrent.totalWithdrawalsRequested, "%"
            );
        }
        if (liquidity.totalWithdrawalsRequested > 0) {
            console2.log(
                "  Liquidity Test:", (liquidity.successfulRequests * 100) / liquidity.totalWithdrawalsRequested, "%"
            );
        }

        console2.log("");
        console2.log("Approval Success Rates:");
        if (batch.totalWithdrawalsApproved > 0) {
            console2.log("  Batch Test:", (batch.successfulApprovals * 100) / batch.totalWithdrawalsApproved, "%");
        }
        if (concurrent.totalWithdrawalsApproved > 0) {
            console2.log(
                "  Concurrent Test:", (concurrent.successfulApprovals * 100) / concurrent.totalWithdrawalsApproved, "%"
            );
        }
        if (liquidity.totalWithdrawalsApproved > 0) {
            console2.log(
                "  Liquidity Test:", (liquidity.successfulApprovals * 100) / liquidity.totalWithdrawalsApproved, "%"
            );
        }

        console2.log("");
        console2.log("Gas Efficiency:");
        console2.log("  Batch Test Avg Gas:", batch.avgGasPerOperation);
        console2.log("  Concurrent Test Avg Gas:", concurrent.avgGasPerOperation);
        console2.log("  Liquidity Test Avg Gas:", liquidity.avgGasPerOperation);

        console2.log("");
        console2.log("Liquidity Usage:");
        console2.log("  Batch Test:", batch.totalLiquidityUsed);
        console2.log("  Concurrent Test:", concurrent.totalLiquidityUsed);
        console2.log("  Liquidity Test:", liquidity.totalLiquidityUsed);

        console2.log("");
        console2.log("==== End of Comparison Report ====");
    }
}
