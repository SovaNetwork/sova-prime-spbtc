# Fuzz Tests Summary

This document summarizes the comprehensive fuzz tests created for the Fountfi protocol.

## Overview

Three fuzz test files have been created to thoroughly test multi-user interactions, stress scenarios, and share calculation accuracy:

1. **MultiUserFuzzTest.t.sol** - Core multi-user interaction scenarios
2. **ProtocolStressFuzzTest.t.sol** - Stress testing and edge cases
3. **ShareCalculationFuzzTest.t.sol** - Share calculation accuracy and precision

## Test Files

### 1. MultiUserFuzzTest.t.sol

Tests fundamental multi-user scenarios with up to 3 concurrent users:

- **testFuzz_MultiUserSequentialDeposits**: Tests sequential deposits by multiple users
- **testFuzz_MixedDepositsWithdrawals**: Tests mixed deposit and withdrawal operations
- **testFuzz_ConcurrentOperations**: Simulates same-block transactions
- **testFuzz_ExtremeScenarios**: Tests dust amounts and maximum amounts

Key Features:
- Tracks user balances and shares for verification
- Verifies proportional ownership is maintained
- Checks protocol invariants after each operation

### 2. ProtocolStressFuzzTest.t.sol

Stress tests the protocol under extreme conditions:

- **testFuzz_RapidSequentialOperations**: Up to 50 rapid operations
- **testFuzz_PriceVolatility**: Tests behavior with NAV/price updates
- **testFuzz_ExtremePatterns**: Tests pyramid, inverse pyramid, and random patterns
- **testFuzz_ManySmallUsers**: Tests with up to 50 concurrent users

Key Features:
- Tests with ReportedStrategy for price volatility scenarios
- Comprehensive state tracking and verification
- Tests extreme deposit/withdrawal patterns

### 3. ShareCalculationFuzzTest.t.sol

Focuses on mathematical accuracy of share calculations:

- **testFuzz_ShareCalculationAcrossScales**: Tests across different decimal scales
- **testFuzz_RoundingFavorsProtocol**: Ensures rounding doesn't create value
- **testFuzz_ExtremeRatios**: Tests with extreme asset-to-share ratios
- **testFuzz_DepositWithdrawCycles**: Tests accuracy across multiple cycles
- **testFuzz_ShareValueMonotonicity**: Ensures share value doesn't decrease
- **testFuzz_ExtremePrecision**: Tests with very small and very large numbers

Key Features:
- Verifies ERC4626 conversion functions remain accurate
- Tests decimal conversion between USDC (6 decimals) and shares (18 decimals)
- Ensures rounding errors are minimal and favor the protocol

## Key Technical Solutions

### 1. Decimal Handling
- Properly handles conversion between USDC (6 decimals) and tRWA shares (18 decimals)
- All deposit amounts use USDC decimal precision (e6)
- Share calculations account for decimal differences

### 2. Mock Infrastructure
- Uses MockRegistry and MockConduit to avoid circular dependencies
- MockStrategy implements required functions for testing
- Proper approval setup for both token and conduit contracts

### 3. Asset Transfer Flow
- Added `transferAssets` function to IStrategy interface
- BasicStrategy implements asset transfers with proper authorization
- tRWA._withdraw properly retrieves assets from strategy before transferring

## Running the Tests

Run all fuzz tests with:
```bash
forge test --match-contract "MultiUserFuzzTest|ProtocolStressFuzzTest|ShareCalculationFuzzTest" -vv --fuzz-runs 100
```

Run individual test files:
```bash
forge test --match-contract MultiUserFuzzTest -vv --fuzz-runs 100
forge test --match-contract ProtocolStressFuzzTest -vv --fuzz-runs 100
forge test --match-contract ShareCalculationFuzzTest -vv --fuzz-runs 100
```

## Test Results

All 14 fuzz tests pass successfully with 100+ fuzz runs:
- MultiUserFuzzTest: 4 tests passing
- ProtocolStressFuzzTest: 4 tests passing
- ShareCalculationFuzzTest: 6 tests passing

The tests verify:
✅ Proportional ownership is maintained across all operations
✅ Share calculations remain accurate with proper decimal handling
✅ Protocol handles extreme scenarios gracefully
✅ Multi-user interactions work correctly
✅ Price volatility doesn't break share calculations
✅ Rounding errors are minimal and controlled