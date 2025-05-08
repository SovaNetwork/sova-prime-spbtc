# GatedMintRWA Implementation Plan

## Overview

The GatedMintRWA contract extends the base tRWA token to introduce a gated minting mechanism. Unlike the standard tRWA, which mints shares immediately upon deposit, GatedMintRWA collects and holds the deposited assets while recording the deposit information. The actual minting only occurs when explicitly approved by the strategy contract.

This implementation enables:
- Two-phase deposit process with explicit approval/rejection
- Time-bounded deposits that can be reclaimed if not processed
- Enhanced control over the minting process for strategy administrators

## Data Structures

```solidity
// Enum to track the deposit state
enum DepositState {
    PENDING,
    ACCEPTED,
    REFUNDED
}

struct PendingDeposit {
    address depositor;       // Address that initiated the deposit
    address recipient;       // Address that will receive shares if approved
    uint256 assetAmount;     // Amount of assets deposited
    uint256 expirationTime;  // Timestamp after which deposit can be reclaimed
    DepositState state;      // Current state of the deposit
}

// Storage for pending deposits
mapping(bytes32 => PendingDeposit) public pendingDeposits;
bytes32[] public depositIds;
mapping(address => bytes32[]) public userDepositIds;

// Deposit expiration time (in seconds) - default to 7 days
uint256 public depositExpirationPeriod = 7 days;
```

## New Functions

### Configuration Functions

```solidity
/**
 * @notice Sets the period after which deposits expire and can be reclaimed
 * @param newExpirationPeriod New expiration period in seconds
 */
function setDepositExpirationPeriod(uint256 newExpirationPeriod) external onlyStrategy;
```

### Deposit Management Functions

```solidity
/**
 * @notice Accept a pending deposit, minting tokens to the recipient
 * @param depositId The unique identifier of the deposit to accept
 * @return True if successful
 */
function acceptDeposit(bytes32 depositId) external onlyStrategy returns (bool);

/**
 * @notice Refund a pending deposit, returning assets to the depositor
 * @param depositId The unique identifier of the deposit to refund
 * @return True if successful
 */
function refundDeposit(bytes32 depositId) external onlyStrategy returns (bool);

/**
 * @notice Allow a user to reclaim their expired deposit
 * @param depositId The unique identifier of the deposit to reclaim
 * @return True if successful
 */
function reclaimDeposit(bytes32 depositId) external returns (bool);

/**
 * @notice Get all pending deposit IDs for a specific user
 * @param user The user address
 * @return Array of deposit IDs
 */
function getUserPendingDeposits(address user) external view returns (bytes32[] memory);

/**
 * @notice Get details for a specific deposit
 * @param depositId The unique identifier of the deposit
 * @return The deposit details
 */
function getDepositDetails(bytes32 depositId) external view returns (PendingDeposit memory);
```

### Internal Utility Functions

```solidity
/**
 * @notice Generate a unique deposit ID
 * @param depositor The depositor address
 * @param recipient The recipient address
 * @param assets The amount of assets
 * @return A unique identifier for the deposit
 */
function _generateDepositId(
    address depositor,
    address recipient,
    uint256 assets
) internal view returns (bytes32);

/**
 * @notice Process deposit status updates
 * @param depositId The deposit ID to process
 * @param newState The new state (ACCEPTED or REFUNDED)
 */
function _processDeposit(bytes32 depositId, DepositState newState) internal;
```

## Override Functions from tRWA

```solidity
/**
 * @notice Override of _deposit to store deposit info instead of minting immediately
 * @param by Address of the sender
 * @param to Address of the recipient
 * @param assets Amount of assets to deposit
 * @param shares Amount of shares to mint
 */
function _deposit(
    address by,
    address to,
    uint256 assets,
    uint256 shares
) internal override {
    // Run hooks (same as in tRWA)
    IHook[] storage opHooks = operationHooks[OP_DEPOSIT];
    for (uint i = 0; i < opHooks.length; i++) {
        IHook.HookOutput memory hookOutput = opHooks[i].onBeforeDeposit(address(this), by, assets, to);
        if (!hookOutput.approved) {
            revert HookCheckFailed(hookOutput.reason);
        }
    }

    // Collect assets
    Conduit(
        Registry(RoleManaged(strategy).registry()).conduit()
    ).collectDeposit(asset(), by, address(this), assets);

    // Instead of minting, store deposit information
    bytes32 depositId = _generateDepositId(by, to, assets);
    pendingDeposits[depositId] = PendingDeposit({
        depositor: by,
        recipient: to,
        assetAmount: assets,
        expirationTime: block.timestamp + depositExpirationPeriod,
        state: DepositState.PENDING
    });

    depositIds.push(depositId);
    userDepositIds[by].push(depositId);

    // Emit a custom event for the pending deposit
    emit DepositPending(depositId, by, to, assets);
}
```

## Events

```solidity
event DepositPending(
    bytes32 indexed depositId,
    address indexed depositor,
    address indexed recipient,
    uint256 assets
);
event DepositAccepted(bytes32 indexed depositId, address indexed recipient, uint256 assets, uint256 shares);
event DepositRefunded(bytes32 indexed depositId, address indexed depositor, uint256 assets);
event DepositReclaimed(bytes32 indexed depositId, address indexed depositor, uint256 assets);
event DepositExpirationPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
```

## Custom Errors

```solidity
error DepositNotFound();
error DepositNotPending();
error DepositNotExpired();
error NotDepositor();
error InvalidExpirationPeriod();
```

## Implementation Details

### Constructor

The constructor should extend the tRWA constructor and also add initialization for the deposit expiration period:

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    address asset_,
    uint8 assetDecimals_,
    address strategy_
) tRWA(name_, symbol_, asset_, assetDecimals_, strategy_) {
    // depositExpirationPeriod initialized with default value (7 days)
}
```

### acceptDeposit Implementation

```solidity
function acceptDeposit(bytes32 depositId) external onlyStrategy returns (bool) {
    PendingDeposit storage deposit = pendingDeposits[depositId];
    if (deposit.depositor == address(0)) revert DepositNotFound();
    if (deposit.state != DepositState.PENDING) revert DepositNotPending();

    deposit.state = DepositState.ACCEPTED;

    // Transfer the assets to the strategy
    SafeTransferLib.safeTransfer(asset(), strategy, deposit.assetAmount);

    // Calculate shares based on current exchange rate
    uint256 shares = previewDeposit(deposit.assetAmount);

    // Mint shares to the recipient
    _mint(deposit.recipient, shares);

    emit DepositAccepted(depositId, deposit.recipient, deposit.assetAmount, shares);
    return true;
}
```

### refundDeposit Implementation

```solidity
function refundDeposit(bytes32 depositId) external onlyStrategy returns (bool) {
    PendingDeposit storage deposit = pendingDeposits[depositId];
    if (deposit.depositor == address(0)) revert DepositNotFound();
    if (deposit.state != DepositState.PENDING) revert DepositNotPending();

    deposit.state = DepositState.REFUNDED;

    // Return assets to the depositor
    SafeTransferLib.safeTransfer(asset(), deposit.depositor, deposit.assetAmount);

    emit DepositRefunded(depositId, deposit.depositor, deposit.assetAmount);
    return true;
}
```

### reclaimDeposit Implementation

```solidity
function reclaimDeposit(bytes32 depositId) external returns (bool) {
    PendingDeposit storage deposit = pendingDeposits[depositId];
    if (deposit.depositor == address(0)) revert DepositNotFound();
    if (deposit.state != DepositState.PENDING) revert DepositNotPending();
    if (deposit.depositor != msg.sender) revert NotDepositor();
    if (block.timestamp < deposit.expirationTime) revert DepositNotExpired();

    deposit.state = DepositState.REFUNDED;

    // Return assets to the depositor
    SafeTransferLib.safeTransfer(asset(), deposit.depositor, deposit.assetAmount);

    emit DepositReclaimed(depositId, deposit.depositor, deposit.assetAmount);
    return true;
}
```

## Security Considerations

1. **Frontrunning Protection**: The strategy should have measures to prevent frontrunning of acceptDeposit/refundDeposit decisions.

2. **Asset Security**: All assets held in the contract need to be properly accounted for and only transferable through the defined mechanisms.

3. **Reentrancy Protection**: Consider adding reentrancy guards to critical functions that transfer tokens.

4. **Expiration Handling**: Ensure that expiration times cannot be manipulated to prematurely reclaim deposits.

5. **Gas Optimization**: Be mindful of array growth in depositIds and userDepositIds. Consider adding cleanup mechanisms for processed deposits.

6. **Handle Edge Cases**:
   - Zero-value deposits
   - Deposits with identical parameters generating the same ID
   - Contract upgrades that might affect pending deposits

## Testing Strategy

Tests should cover the following scenarios:

1. Standard flow: deposit → accept → shares received
2. Refund flow: deposit → refund → assets returned
3. Expiration flow: deposit → wait for expiration → reclaim
4. Attempt to reclaim before expiration (should fail)
5. Attempt to process already processed deposit (should fail)
6. Interaction with hooks system (should behave as with regular tRWA)

## Integration Considerations

1. **Deposit Duration**: Strategies using this token should account for the delay between deposit and share minting.

2. **UI/UX Implications**: Users need visibility into pending, accepted, and rejected deposits.

3. **Oracle Interactions**: Price oracle integrations may need to account for assets held but not yet associated with shares.

4. **Strategy Withdrawals**: The strategy must ensure it doesn't withdraw assets representing pending deposits.

5. **Deposit Expiration Period**: The default 7-day period should be appropriate for most use cases, but strategies may need to adjust this period based on their specific operational requirements.

## Future Extensions

1. **Partial Acceptances**: Allow strategies to partially accept deposits.

2. **Batch Processing**: Enable processing multiple deposits in a single transaction, with all deposits in the batch receiving equal "post-money" share treatment.

3. **Holding Contract**: Move tokens representing pending deposits to a separate holding contract, which strategists can then call to accept

5. **Delegated Reclaiming**: Allow depositors to delegate reclaiming rights to other addresses.