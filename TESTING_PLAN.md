# Testing Plan to Achieve 100% Coverage

## Current Coverage Status
- **Total Coverage**: 61.17% lines, 55.54% statements, 41.74% branches, 72.41% functions
- **Target**: 100% coverage across all metrics

## Critical Zero-Coverage Contracts

### 1. GatedMintEscrow.sol (0% coverage)
**Priority: HIGH** - 87 lines uncovered

**Required Test Suite: `GatedMintEscrow.t.sol`**

**Test Categories:**
- **Constructor Tests**
  - Valid initialization with correct addresses
  - Revert on zero addresses for token, asset, or strategy
  
- **Deposit Handling Tests**
  - `handleDepositReceived()` - successful deposit creation
  - `handleDepositReceived()` - unauthorized caller (not token)
  - Verify deposit storage and accounting updates
  - Event emission verification

- **Single Deposit Operations**
  - `acceptDeposit()` - successful acceptance by strategy
  - `acceptDeposit()` - unauthorized caller
  - `acceptDeposit()` - deposit not found
  - `acceptDeposit()` - deposit not pending (already processed)
  - `refundDeposit()` - successful refund by strategy
  - `refundDeposit()` - unauthorized/invalid scenarios

- **Batch Operations**
  - `batchAcceptDeposits()` - successful batch processing
  - `batchAcceptDeposits()` - empty array handling
  - `batchAcceptDeposits()` - mixed valid/invalid deposits
  - `batchRefundDeposits()` - successful batch refunds
  - Verify round increment behavior

- **User Reclaim Tests**
  - `reclaimDeposit()` - successful reclaim after expiration
  - `reclaimDeposit()` - reclaim before expiration (should fail)
  - `reclaimDeposit()` - unauthorized user attempts
  - `reclaimDeposit()` - already processed deposits

- **View Function Tests**
  - `getPendingDeposit()` - correct data retrieval
  - Accounting verification (totalPendingAssets, userPendingAssets)
  - Current round tracking

### 2. GatedMintRWAStrategy.sol (0% coverage)
**Priority: HIGH** - 3 lines uncovered

**Required Test Suite: `GatedMintRWAStrategy.t.sol`**

**Test Categories:**
- **Token Deployment Tests**
  - `_deployToken()` - successful GatedMintRWA deployment
  - Verify correct parameters passed to constructor
  - Integration with parent ReportedStrategy

### 3. ManagedWithdrawRWAStrategy.sol (0% coverage)
**Priority: HIGH** - 35 lines uncovered

**Required Test Suite: `ManagedWithdrawRWAStrategy.t.sol`**

**Test Categories:**
- **Initialization Tests**
  - `initialize()` - successful initialization with valid parameters
  - EIP-712 domain separator setup verification
  - Parent class initialization

- **Token Deployment Tests**
  - `_deployToken()` - successful ManagedWithdrawRWA deployment
  - Parameter validation

- **Withdrawal Processing Tests**
  - `redeem()` - successful single redemption with valid signature
  - `redeem()` - expired request rejection
  - `redeem()` - nonce reuse prevention
  - `redeem()` - invalid signature rejection
  - `batchRedeem()` - successful batch processing
  - `batchRedeem()` - array length mismatch
  - `batchRedeem()` - mixed valid/invalid requests

- **Signature Verification Tests**
  - `_verifySignature()` - valid EIP-712 signatures
  - `_verifySignature()` - invalid signatures
  - `_validateRedeem()` - expiration and nonce checks

- **Nonce Management Tests**
  - Nonce usage tracking
  - Event emission for consumed nonces

### 4. GatedMintRWA.sol (0% coverage)
**Priority: HIGH** - 51 lines uncovered

**Required Test Suite: `GatedMintRWA.t.sol`**

**Test Categories:**
- **Constructor Tests**
  - Successful initialization with escrow deployment
  - Parameter validation

- **Configuration Tests**
  - `setDepositExpirationPeriod()` - valid period updates
  - `setDepositExpirationPeriod()` - invalid periods (zero, too high)
  - Event emission verification

- **Deposit Flow Tests**
  - `_deposit()` - successful deposit processing with hooks
  - `_deposit()` - hook rejection scenarios
  - Deposit ID generation and tracking
  - Asset transfer to escrow

- **Share Minting Tests**
  - `mintShares()` - successful single mint by escrow
  - `mintShares()` - unauthorized caller rejection
  - `batchMintShares()` - successful batch minting
  - `batchMintShares()` - array length validation
  - Exchange rate calculations

- **View Function Tests**
  - `getUserPendingDeposits()` - correct filtering
  - `getDepositDetails()` - accurate data retrieval
  - Deposit state tracking

### 5. ManagedWithdrawRWA.sol (0% coverage)
**Priority: HIGH** - 36 lines uncovered

**Required Test Suite: `ManagedWithdrawRWA.t.sol`**

**Test Categories:**
- **Constructor Tests**
  - Successful initialization
  - Parameter validation

- **Withdrawal Restrictions**
  - `withdraw()` - should always revert with UseRedeem error
  - Function override behavior

- **Redemption Tests**
  - `redeem()` - successful single redemption by strategy
  - `redeem()` - maximum redemption limits
  - `redeem()` with minimum assets - successful case
  - `redeem()` with minimum assets - insufficient assets error
  - `batchRedeemShares()` - successful batch processing
  - `batchRedeemShares()` - array length validation
  - `batchRedeemShares()` - minimum assets enforcement

- **Asset Collection Tests**
  - `_collect()` - successful asset transfer from strategy
  - Integration with strategy contract

## Moderate Coverage Gaps

### 6. Registry.sol (80% lines coverage)
**Priority: MEDIUM** - Improve branch coverage (50%) and function coverage (75%)

**Additional Tests Needed:**
- Edge cases in `deployStrategy()` 
- Error conditions in asset/hook management
- Complete coverage of all conditional branches
- Missing function coverage (likely private/internal functions)

### 7. RoleManager.sol (92.68% lines coverage)
**Priority: MEDIUM** - Improve statement (81.63%) and branch coverage (41.67%)

**Additional Tests Needed:**
- Edge cases in role hierarchy management
- Complex conditional branches in role checking
- Error conditions and edge cases

### 8. tRWA.sol (80.65% lines coverage)
**Priority: MEDIUM** - Improve statement and branch coverage

**Additional Tests Needed:**
- Complex hook scenarios and edge cases
- Error conditions in hook management
- Withdrawal queue edge cases
- Transfer hook interactions

## Implementation Strategy

### Phase 1: Zero Coverage Contracts (Week 1)
1. **GatedMintEscrow.t.sol** - Complete test suite
2. **ManagedWithdrawRWA.t.sol** - Complete test suite
3. **GatedMintRWA.t.sol** - Complete test suite

### Phase 2: Strategy Contracts (Week 1)
1. **GatedMintRWAStrategy.t.sol** - Simple but complete
2. **ManagedWithdrawRWAStrategy.t.sol** - Complex signature testing

### Phase 3: Coverage Improvement (Week 2)
1. **Registry.t.sol** - Add missing edge cases
2. **RoleManager.t.sol** - Add complex role scenarios
3. **tRWA.t.sol** - Add missing hook and withdrawal scenarios

## Test Infrastructure Requirements

### Mock Contracts Needed
- Enhanced MockERC20 with failure modes
- MockStrategy with configurable behaviors
- MockHook with various response modes
- Signature generation utilities for EIP-712 testing

### Test Utilities
- Deposit ID generation helpers
- Signature creation utilities
- Time manipulation helpers
- Event assertion utilities
- Fuzzing setup for edge cases

## Expected Coverage Improvement
- **GatedMintEscrow**: 0% → 100% (+87 lines)
- **Strategy Contracts**: 0% → 100% (+38 lines)
- **Token Contracts**: ~40% → 100% (+87 lines)
- **Existing Contracts**: +80% → 95%+ (+30 lines)

**Total Expected**: 61% → 100% coverage across all metrics

## Success Criteria
- [ ] All contracts achieve 100% line coverage
- [ ] All contracts achieve 95%+ branch coverage
- [ ] All contracts achieve 100% function coverage
- [ ] All edge cases and error conditions tested
- [ ] Integration tests verify cross-contract interactions
- [ ] Fuzzing tests validate complex scenarios