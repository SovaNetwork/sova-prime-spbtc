// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IBtcVaultStrategy} from "src/interfaces/IBtcVaultStrategy.sol";
import {IBtcVaultShareToken} from "src/interfaces/IBtcVaultShareToken.sol";

contract LoadTestScript is Script {
    // Deployed contract addresses on Base Sepolia
    address constant BTC_VAULT_STRATEGY = 0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8;
    address constant BTC_VAULT_TOKEN = 0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a;
    
    // Test collateral tokens
    address constant WBTC_TOKEN = 0xe44b2870eFcd6Bb3C9305808012621f438e9636D;
    address constant SOVABTC_TOKEN = 0x9901Bdc36a2fD60aF17ca28c960e1FF2f968e426;
    
    // Test parameters
    uint256 constant DEPOSIT_AMOUNT = 0.01 ether; // 0.01 BTC worth
    uint256 constant USERS_NORMAL = 10;
    uint256 constant USERS_PEAK = 50;
    uint256 constant USERS_STRESS = 100;
    
    struct LoadTestResult {
        uint256 totalDeposits;
        uint256 successfulDeposits;
        uint256 failedDeposits;
        uint256 totalGasUsed;
        uint256 avgGasPerDeposit;
        uint256 minGas;
        uint256 maxGas;
        uint256 startTime;
        uint256 endTime;
        uint256 totalDuration;
    }
    
    function run() external {
        console2.log("==== BTC Vault Load Test Starting ====");
        console2.log("Strategy:", BTC_VAULT_STRATEGY);
        console2.log("Token:", BTC_VAULT_TOKEN);
        console2.log("");
        
        // Run different load scenarios
        LoadTestResult memory normalLoad = runNormalLoadTest();
        reportResults("Normal Load Test", normalLoad);
        
        LoadTestResult memory peakLoad = runPeakLoadTest();
        reportResults("Peak Load Test", peakLoad);
        
        LoadTestResult memory stressTest = runStressTest();
        reportResults("Stress Test", stressTest);
        
        // Generate comparison report
        generateComparisonReport(normalLoad, peakLoad, stressTest);
    }
    
    function runNormalLoadTest() internal returns (LoadTestResult memory) {
        console2.log("Running Normal Load Test...");
        console2.log("Users:", USERS_NORMAL);
        console2.log("Deposits per user: 5");
        console2.log("Interval: 1 second");
        
        return executeLoadTest(USERS_NORMAL, 5, 1000);
    }
    
    function runPeakLoadTest() internal returns (LoadTestResult memory) {
        console2.log("Running Peak Load Test...");
        console2.log("Users:", USERS_PEAK);
        console2.log("Deposits per user: 2");
        console2.log("Interval: 100ms");
        
        return executeLoadTest(USERS_PEAK, 2, 100);
    }
    
    function runStressTest() internal returns (LoadTestResult memory) {
        console2.log("Running Stress Test...");
        console2.log("Users:", USERS_STRESS);
        console2.log("Deposits per user: 1");
        console2.log("Interval: Simultaneous");
        
        return executeLoadTest(USERS_STRESS, 1, 0);
    }
    
    function executeLoadTest(
        uint256 userCount,
        uint256 depositsPerUser,
        uint256 intervalMs
    ) internal returns (LoadTestResult memory result) {
        result.startTime = block.timestamp;
        result.minGas = type(uint256).max;
        
        IBtcVaultShareToken vault = IBtcVaultShareToken(BTC_VAULT_TOKEN);
        IERC20 wbtc = IERC20(WBTC_TOKEN);
        IERC20 sovaBtc = IERC20(SOVABTC_TOKEN);
        
        // Generate test users
        address[] memory users = generateTestUsers(userCount);
        
        // Fund users with test tokens
        fundTestUsers(users, depositsPerUser);
        
        // Execute deposits
        for (uint256 i = 0; i < users.length; i++) {
            for (uint256 j = 0; j < depositsPerUser; j++) {
                // Alternate between WBTC and sovaBTC deposits
                address collateral = (i + j) % 2 == 0 ? WBTC_TOKEN : SOVABTC_TOKEN;
                
                uint256 gasBefore = gasleft();
                
                vm.startPrank(users[i]);
                
                try vault.depositCollateral(collateral, DEPOSIT_AMOUNT, users[i]) returns (uint256) {
                    result.successfulDeposits++;
                    
                    uint256 gasUsed = gasBefore - gasleft();
                    result.totalGasUsed += gasUsed;
                    
                    if (gasUsed < result.minGas) result.minGas = gasUsed;
                    if (gasUsed > result.maxGas) result.maxGas = gasUsed;
                    
                } catch {
                    result.failedDeposits++;
                }
                
                vm.stopPrank();
                
                result.totalDeposits++;
                
                // Apply interval delay if specified
                if (intervalMs > 0 && i < users.length - 1) {
                    vm.warp(block.timestamp + intervalMs / 1000);
                }
            }
        }
        
        result.endTime = block.timestamp;
        result.totalDuration = result.endTime - result.startTime;
        
        if (result.successfulDeposits > 0) {
            result.avgGasPerDeposit = result.totalGasUsed / result.successfulDeposits;
        }
        
        return result;
    }
    
    function generateTestUsers(uint256 count) internal pure returns (address[] memory) {
        address[] memory users = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            users[i] = address(uint160(0x1000000 + i));
        }
        return users;
    }
    
    function fundTestUsers(address[] memory users, uint256 depositsPerUser) internal {
        uint256 amountPerUser = DEPOSIT_AMOUNT * depositsPerUser;
        
        for (uint256 i = 0; i < users.length; i++) {
            // Fund with both WBTC and sovaBTC
            vm.deal(users[i], 1 ether); // Gas money
            
            // Note: Users need to be funded with tokens before running this script
            // On testnet, use faucets or manual transfers to fund test accounts
            
            // Approve strategy
            vm.startPrank(users[i]);
            IERC20(WBTC_TOKEN).approve(BTC_VAULT_STRATEGY, type(uint256).max);
            IERC20(SOVABTC_TOKEN).approve(BTC_VAULT_STRATEGY, type(uint256).max);
            vm.stopPrank();
        }
    }
    
    function reportResults(string memory testName, LoadTestResult memory result) internal pure {
        console2.log("");
        console2.log("====", testName, "Results ====");
        console2.log("Total Deposits Attempted:", result.totalDeposits);
        console2.log("Successful Deposits:", result.successfulDeposits);
        console2.log("Failed Deposits:", result.failedDeposits);
        console2.log("Success Rate:", (result.successfulDeposits * 100) / result.totalDeposits, "%");
        console2.log("Total Gas Used:", result.totalGasUsed);
        console2.log("Average Gas per Deposit:", result.avgGasPerDeposit);
        console2.log("Min Gas:", result.minGas);
        console2.log("Max Gas:", result.maxGas);
        console2.log("Total Duration:", result.totalDuration, "seconds");
        console2.log("");
    }
    
    function generateComparisonReport(
        LoadTestResult memory normal,
        LoadTestResult memory peak,
        LoadTestResult memory stress
    ) internal pure {
        console2.log("==== Load Test Comparison Report ====");
        console2.log("");
        
        console2.log("Success Rates:");
        console2.log("  Normal Load:", (normal.successfulDeposits * 100) / normal.totalDeposits, "%");
        console2.log("  Peak Load:", (peak.successfulDeposits * 100) / peak.totalDeposits, "%");
        console2.log("  Stress Test:", (stress.successfulDeposits * 100) / stress.totalDeposits, "%");
        console2.log("");
        
        console2.log("Average Gas per Deposit:");
        console2.log("  Normal Load:", normal.avgGasPerDeposit);
        console2.log("  Peak Load:", peak.avgGasPerDeposit);
        console2.log("  Stress Test:", stress.avgGasPerDeposit);
        console2.log("");
        
        console2.log("Throughput (deposits/second):");
        if (normal.totalDuration > 0) {
            console2.log("  Normal Load:", normal.successfulDeposits / normal.totalDuration);
        }
        if (peak.totalDuration > 0) {
            console2.log("  Peak Load:", peak.successfulDeposits / peak.totalDuration);
        }
        if (stress.totalDuration > 0) {
            console2.log("  Stress Test:", stress.successfulDeposits / stress.totalDuration);
        }
        console2.log("");
        
        console2.log("Performance Analysis:");
        if (normal.avgGasPerDeposit > 0) {
            uint256 gasIncreasePeak = ((peak.avgGasPerDeposit - normal.avgGasPerDeposit) * 100) / normal.avgGasPerDeposit;
            uint256 gasIncreaseStress = ((stress.avgGasPerDeposit - normal.avgGasPerDeposit) * 100) / normal.avgGasPerDeposit;
            
            console2.log("  Gas increase at peak load:", gasIncreasePeak, "%");
            console2.log("  Gas increase at stress load:", gasIncreaseStress, "%");
        }
        
        console2.log("");
        console2.log("==== End of Report ====");
    }
}