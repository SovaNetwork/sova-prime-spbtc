# Price Per Share Implementation Plan

## Overview
Transition from AUM-based to price-per-share-based accounting with hybrid tracking for optimal accuracy. This approach stores the price per share from oracle updates and multiplies by current total supply to get `totalAssets`, while tracking any edge case adjustments.

## Recommended Hybrid Architecture

### Core Concept
- Oracle reports: `pricePerShare = AUM / totalSupply` at time of update
- Real-time calculation: `totalAssets = pricePerShare * currentTotalSupply + adjustments`
- Adjustments handle edge cases (flows between oracle snapshot and update)

## File Changes Required

### 1. AumOracleReporter.sol
**Changes:**
- Modify `update()` function signature to accept `pricePerShare` instead of raw AUM
- Update storage variable from `uint256 aum` to `uint256 pricePerShare`
- Update `report()` function to return `pricePerShare`
- Add input validation for reasonable price ranges
- Consider adding `lastUpdateTotalSupply` for transparency/debugging

**New Interface:**
```solidity
function update(uint256 newPricePerShare) external;
function report() external view returns (uint256 pricePerShare);
```

### 2. ReportedStrategy.sol
**Changes:**
- Remove `balance()` function (or deprecate)
- Add `pricePerShare()` function that delegates to reporter
- Add `calculateTotalAssets()` function that computes `pricePerShare * tRWA.totalSupply()`
- Add optional adjustment tracking for edge cases:
  - `uint256 priceAdjustment` (can be positive/negative via int256)
  - Functions to set/clear adjustments
- Update any existing balance-related logic

**New Interface:**
```solidity
function pricePerShare() external view returns (uint256);
function calculateTotalAssets() external view returns (uint256);
function setPriceAdjustment(int256 adjustment) external; // admin only
```

### 3. tRWA.sol
**Changes:**
- Modify `totalAssets()` to call `strategy.calculateTotalAssets()`
- Ensure share minting/burning uses `strategy.pricePerShare()` directly for pricing
- Verify no circular dependencies in deposit/withdraw flows
- Add precision handling for edge cases with small amounts

**Key Implementation Notes:**
- `totalAssets()` must NOT be used during share price calculations
- Use `pricePerShare()` directly in `_convertToShares` and `_convertToAssets`

### 4. Test Files to Update

#### ReportedStrategy.t.sol
- Update tests to use new price-per-share interface
- Add tests for `calculateTotalAssets()` accuracy
- Test adjustment mechanism edge cases
- Test precision handling with various total supply amounts

#### tRWA.t.sol  
- Update `totalAssets()` tests to verify price * supply calculation
- Test deposit/withdraw flows don't create circular dependencies
- Add edge case tests for small amounts and precision

#### Integration.t.sol
- End-to-end tests with full oracle update → deposit → withdraw flows
- Verify ERC4626 compliance with new accounting method
- Test scenarios with adjustments applied

### 5. Deployment Scripts
**script/DeployStrategy.s.sol:**
- Update deployment to initialize with price-per-share approach
- Ensure proper initial price setting (typically 1e18 for 1:1 ratio)

## Implementation Phases

### Phase 1: Core Infrastructure
1. Update `AumOracleReporter` for price-per-share storage and interface
2. Add price calculation logic to `ReportedStrategy`
3. Update basic tests for new interface

### Phase 2: Strategy Integration  
1. Implement `calculateTotalAssets()` in `ReportedStrategy`
2. Add adjustment mechanism for edge cases
3. Comprehensive testing of calculation accuracy

### Phase 3: tRWA Integration
1. Update `totalAssets()` implementation in `tRWA`
2. Verify share pricing uses direct price-per-share (no circular deps)
3. Integration testing for full deposit/withdraw flows

### Phase 4: Edge Case Handling
1. Implement and test adjustment mechanism
2. Add monitoring/alerting for large discrepancies
3. Operational procedures for managing adjustments

## Key Implementation Considerations

### Precision & Math
- Use consistent decimal precision (recommend 18 decimals)
- Handle multiplication overflow for large supplies
- Round appropriately to prevent dust accumulation

### Circular Dependency Prevention
- Share minting MUST use `strategy.pricePerShare()` directly
- Never use `totalAssets()` in share price calculations
- Careful ordering in deposit/withdraw functions

### Edge Case Management
- Track timestamp of last oracle update
- Monitor for significant flows between oracle snapshot and update
- Implement adjustment mechanism with proper access controls

### Operational Procedures
- Oracle must calculate price-per-share at exact `totalSupply` moment
- Clear process for applying adjustments when needed
- Monitoring dashboards for price accuracy

## Migration Strategy

1. Deploy updated contracts to testnet
2. Thorough testing with various scenarios
3. Coordinate oracle update process changes
4. Deploy to mainnet with careful initial price setting
5. Monitor closely for first few update cycles

## Success Metrics

- `totalAssets()` accurately reflects deposits/withdrawals immediately
- Investment performance updates properly on oracle reports
- No circular dependency issues in share pricing
- ERC4626 compliance maintained
- Precision errors < 0.01% under normal operations