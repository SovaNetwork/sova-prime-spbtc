# Escrow-based GatedMintRWA Design

## Overview

This document outlines a revised design for the GatedMintRWA implementation that uses a separate Escrow contract to address permission concerns. The primary objective is to allow the strategy manager to have direct control over deposit acceptance without complex permission setups.

## Architecture

The implementation consists of three main components:

1. **GatedMintRWA Token**:
   - Records and tracks deposit information
   - Mints shares when deposits are accepted
   - Delegates asset custody to the Escrow contract

2. **Escrow Contract**:
   - Holds assets during the pending deposit phase
   - Provides direct functions for the manager to accept/refund deposits
   - Communicates back to the GatedMintRWA token

3. **GatedMintRWAStrategy**:
   - Deploys and configures both the GatedMintRWA token and Escrow
   - Sets up the relationships between contracts

## Flow Diagram

```
User ──(deposit)──> GatedMintRWA ──(assets)──> Escrow
                       │                │
                       │                │
                       │                ▼
                       │         Manager Decision
                       │            /     \
                       │           /       \
                       │      Accept      Refund
                       │         │           │
                       │         │           │
                       │         ▼           ▼
                       │     Strategy     Depositor
                       │         │
                       │         │
                       ▼         │
                 Mint Shares <───┘
```

## Benefits of Escrow Approach

1. **Clear Permission Model**:
   - Strategy manager has direct control over Escrow
   - No need for complex permission delegation or wrapper functions

2. **Proper Separation of Concerns**:
   - GatedMintRWA handles share accounting
   - Escrow handles asset custody
   - Strategy handles business logic

3. **Enhanced Security**:
   - Assets are held in a dedicated contract
   - Clear state transitions and asset movements

4. **Simplified Interface**:
   - Manager interacts directly with Escrow's `acceptDeposit` and `refundDeposit` functions
   - No need to encode function calls or use callStrategyToken

## Implementation

The implementation involves three separate contracts:

1. **GatedMintRWA.sol**:
   - Records deposit information and emits events
   - Delegates asset transfers to Escrow
   - Exposes mintShares for Escrow to call
   - Tracks deposit states

2. **Escrow.sol**:
   - Receives and holds deposited assets
   - Exposes acceptDeposit and refundDeposit functions to manager
   - Calls back to GatedMintRWA when action is taken

3. **GatedMintRWAStrategy.sol**:
   - Creates and configures both contracts
   - Sets up proper permissions

## Permission Design

- **GatedMintRWA**: Controlled by Strategy
- **Escrow**: Controlled by both Strategy and Manager
- **Manager**: Has direct control over Escrow

This design resolves the original permission issue by allowing the manager to directly control the deposit acceptance process without going through the strategy.

## Additional Considerations

1. **Gas Efficiency**:
   - Additional contract layer adds some overhead
   - Compensated by clearer permissions and reduced complexity

2. **Future Extension Pathways**:
   - Can add batch processing in Escrow
   - Can enhance deposit criteria and rules in Escrow
   - Can add more sophisticated asset management in Escrow

3. **Migration Path**:
   - New strategies can use this architecture 
   - Existing strategies might require more complex upgrade path