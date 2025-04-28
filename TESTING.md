# Fountfi Testing Plan to Achieve 100% Coverage

## IMPORTANT: Do not update contract architecture at all when executing the testing plan. This means no new contracts should be created, and no existing contracts should be deleted.

## Current Test Coverage Status

Based on the coverage analysis, the current coverage statistics (excluding test files) are:
- Lines: 55.83% (445/797)
- Statements: 51.82% (427/824)
- Branches: 45.31% (58/128)
- Functions: 58.54% (96/164)

The following key areas have low or zero coverage:
1. `src/strategy/BasicStrategy.sol`: 0% coverage
2. `src/strategy/ReportedStrategy.sol`: 0% coverage
3. `src/token/tRWA.sol`: 9.38% coverage

**Note:** We don't need coverage for mock contracts or deployment scripts (`script/SimpleRWADeploy.s.sol`), as they are not part of the production code.

## Recent Project Changes

The project recently removed the managers directory with these contracts:
- `WithdrawalManager.sol`
- `SubscriptionManager.sol`
- `MerkleHelper.sol`

This might explain why some tests were failing with "Unauthorized" errors, as they were relying on these contracts.

**Note**: Tests were fixed without reintroducing any manager contracts.

## Test Development Plan

To achieve 100% coverage, we'll execute the following testing plan in order of priority:

### 1. Fix Existing Test Failures (Priority: High) ✅

- [x] Review and fix `SubscriptionController` tests to replace functionality previously in `SubscriptionManager`
- [x] Implement proper authorization for controller tests

### 2. Strategy Coverage (Priority: High) ✅

- [x] Create comprehensive tests for `BasicStrategy.sol` (now 100% coverage)
  - Implemented tests for initialization parameters
  - Implemented tests for deposit/withdraw functionality
  - Implemented tests for asset management functions
  - Implemented tests for accounting and share calculations
  - Implemented tests for access control

- [x] Create comprehensive tests for `ReportedStrategy.sol` (now 100% coverage)
  - Implemented tests for reporter integration
  - Implemented tests for NAV calculation
  - Implemented tests for asset valuation updates
  - Implemented tests for share price calculations

### 3. Token Coverage (Priority: High)

- [ ] Expand tests for `tRWA.sol` (only 9.38% coverage)
  - Test ERC20 functionality
  - Test ERC4626 compliance
  - Test deposit/mint/withdraw/redeem with rules validation
  - Test administrative functions
  - Test callbacks during token operations
  - Test share calculations

### 4. Controller Coverage (Priority: Medium) ✅

- [x] Add tests for `SubscriptionController.sol` (now 97.50% coverage)
  - Implemented tests for subscription creation
  - Implemented tests for validation
  - Implemented tests for round management
  - Implemented tests for callbacks
  - Implemented tests for error conditions

- [x] Add tests for `SubscriptionControllerRule.sol` (now 100% coverage)
  - Implemented tests for rule evaluations
  - Implemented tests for controller integration
  - Implemented tests for validation

### 5. Auth and Role Management Coverage (Priority: Medium)

- [ ] Improve `RoleManaged.sol` coverage (75% → 100%)
- [ ] Improve `RoleManager.sol` coverage (52.11% → 100%)

## Test Approach

For each component that needs coverage:

1. Start with unit tests focusing on individual functions
2. Add integration tests for interactions between components
3. Test error conditions and edge cases
4. Test administrative functions with appropriate roles
5. Use property-based testing for invariants where appropriate

## Implementation Strategy

1. Fix authorization issues first by implementing proper role setup in test fixtures
2. Focus on high-priority components (Strategy and Token) first
3. Address controllers next
4. Improve role management test coverage

## Best Practices to Follow

1. Use proper test naming: `test_<FunctionName>_<Scenario>`
2. Group related tests together
3. Use clear assertions with descriptive messages
4. Document complex test setups
5. Use test fixtures and utilities to avoid duplication
6. Run coverage analysis after each major test addition

## Final Verification

Once all tests are implemented:
1. Run complete coverage analysis
2. Address any remaining gaps
3. Validate that all components reach 100% coverage
4. Ensure tests are maintainable and clear