# Fountfi Managers System

This document describes the Withdrawal and Subscription manager system for the Fountfi protocol.

## Overview

Fountfi implements a flexible system for managing withdrawals and subscriptions using dedicated manager contracts with three key components:

1. **Manager Contracts**: Handle complex state management (withdrawal queue, subscription payments)
2. **Rule Contracts**: Route operations to managers when appropriate
3. **Callback System**: Enables communication between external contracts and the tRWA token

## Core Components

### 1. tRWA Token
- Extended with callback functionality
- Supports redirected withdrawals
- Can be integrated with manager contracts
- Burns and mints shares as required

### 2. Withdrawal Management
- **WithdrawalManager**: Handles queued withdrawals and approval process
- **WithdrawalQueueRule**: Redirects withdrawal requests to the queue
- **MerkleHelper**: Provides utilities for Merkle tree operations

### 3. Subscription Management
- **SubscriptionManager**: Manages recurring payments and subscription state
- **SubscriptionRules**: Controls who can deposit based on subscription status
- Supports fee collection and distribution

## Withdrawal System

The withdrawal system implements a phased approach:

1. **Request Phase**: Users request withdrawals which are added to a queue
2. **Approval Phase**: Strategy owners approve withdrawals using a Merkle tree
3. **Execution Phase**: Users execute their approved withdrawals with a proof
4. **Closing Phase**: Withdrawal periods close after expiration or completion

### How to Use Withdrawal System

#### As a User
1. Request a withdrawal using standard ERC4626 methods
```solidity
tRWA.withdraw(assets, receiver, owner);
// or
tRWA.redeem(shares, receiver, owner);
```

2. When approved, execute your withdrawal
```solidity
withdrawalManager.executeWithdrawal(requestId, merkleProof);
```

#### As a Manager
1. Process withdrawal requests
```solidity
// Approve specific withdrawals
withdrawalManager.approveWithdrawals(requestIds);

// Open a withdrawal period
withdrawalManager.openWithdrawalPeriod(
    duration,
    merkleRoot,
    totalAssets
);
```

2. Generate Merkle tree and proofs (off-chain)
```javascript
// Using withdrawalUtils.js
const merkleData = generateMerkleTree(withdrawalRequests);
```

## Subscription System

The subscription system enables recurring payments and deposit management:

1. **Subscription Creation**: Users register for regular deposits
2. **Payment Processing**: Payments are processed at regular intervals
3. **Round Management**: Subscription rounds can be opened and closed
4. **Subscription Updates**: Subscriptions can be modified or cancelled

### How to Use Subscription System

#### As a User
1. Create a subscription
```solidity
subscriptionManager.createSubscription(
    user,
    amount,
    frequency,
    metadata
);
```

2. Cancel a subscription
```solidity
subscriptionManager.cancelSubscription(subscriptionId);
```

#### As a Manager
1. Process payments
```solidity
// Process a single subscription
subscriptionManager.processPayment(subscriptionId);

// Process multiple subscriptions
subscriptionManager.batchProcessPayments(subscriptionIds);
```

2. Manage subscription rounds
```solidity
// Open a round
subscriptionManager.openSubscriptionRound(
    name,
    startTime,
    endTime,
    capacity
);

// Close a round
subscriptionManager.closeSubscriptionRound();
```

## Callback System

The callback system enables external contracts to receive notifications when token operations complete:

```solidity
// Using callback-enabled operations
tRWA.withdraw(
    assets,
    receiver,
    owner,
    true, // use callback
    callbackData
);
```

To receive callbacks, implement the ICallbackReceiver interface:

```solidity
function operationCallback(
    bytes32 operationType,
    bool success,
    bytes memory data
) external {
    // Handle the callback
}
```

## Security Considerations

1. **Role-Based Access Control**: Both managers implement fine-grained access control
2. **Merkle Tree Verification**: Cryptographic verification of approved withdrawals
3. **Fee Management**: Configurable fees with safeguards against excessive fees
4. **Temporal Safety**: Time-bound periods protect against exploitation
5. **Callback Safety**: Callbacks are wrapped in try/catch to prevent reverts

## Testing

Test coverage is provided for both managers:
- `WithdrawalManager.t.sol`: Tests for the withdrawal queue system
- `SubscriptionManager.t.sol`: Tests for the subscription system

## Integration Guide

To add the withdrawal and subscription system to your deployment:

1. Deploy the manager contracts
2. Deploy the rule contracts with references to managers
3. Configure your tRWA token to use the rules
4. Grant appropriate roles to administrators

The system is designed to be modular, allowing you to use one or both managers as needed.