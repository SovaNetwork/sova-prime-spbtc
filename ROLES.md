# Fountfi Protocol Role Management System

## Overview

This document outlines the role-based access control (RBAC) system for the Fountfi protocol, designed to ensure secure and efficient protocol administration while adhering to the principles of least privilege and operational flexibility.

## Role Hierarchy

### Root Roles

- **PROTOCOL_ADMIN**: Highest-level role that can grant/revoke all other roles

### Functional Roles

- **REGISTRY_ADMIN**: Manages protocol components in the registry
- **STRATEGY_ADMIN**: Manages strategy parameters and administration
- **KYC_ADMIN**: Manages compliance requirements and KYC processes
- **REPORTER_ADMIN**: Manages price oracles and data reporting systems
- **SUBSCRIPTION_ADMIN**: Manages investor subscription processes
- **WITHDRAWAL_ADMIN**: Manages withdrawal mechanisms and processes

### Operational Roles

- **STRATEGY_MANAGER**: Day-to-day operation of specific strategies
- **KYC_OPERATOR**: Handles individual user KYC approvals/denials
- **DATA_PROVIDER**: Submits price and valuation updates to reporters

## Contract-Specific Roles

### Registry Contract
- PROTOCOL_ADMIN: Can manage REGISTRY_ADMIN
- REGISTRY_ADMIN: Can add/remove strategies, rules, assets

### Strategy Contracts
- STRATEGY_ADMIN: Can manage STRATEGY_MANAGER, update reporter for a reported strategy
- STRATEGY_MANAGER: Can manage the strategy's `onlyManager` functions

### tRWA Token
- None

### Rules/KYC
- KYC_ADMIN: Can set compliance parameters, manage KYC_OPERATOR
- KYC_OPERATOR: Can approve/deny individual addresses

### Reporter Contracts
- REPORTER_ADMIN: Can configure oracle parameters
- DATA_PROVIDER: Can submit price updates

### Manager Contracts
- SUBSCRIPTION_ADMIN: Can manage subscription processes
- WITHDRAWAL_ADMIN: Can manage withdrawal processes

## Role Administration

| Role | Administered By |
|------|----------------|
| PROTOCOL_ADMIN | Self (multi-sig recommended) |
| REGISTRY_ADMIN | PROTOCOL_ADMIN |
| STRATEGY_ADMIN | PROTOCOL_ADMIN |
| KYC_ADMIN | PROTOCOL_ADMIN |
| REPORTER_ADMIN | PROTOCOL_ADMIN |
| SUBSCRIPTION_ADMIN | PROTOCOL_ADMIN |
| WITHDRAWAL_ADMIN | PROTOCOL_ADMIN |
| KYC_OPERATOR | KYC_ADMIN |
| DATA_PROVIDER | REPORTER_ADMIN |

## Implementation Approach

### Role Manager Design

We recommend implementing a hybrid approach:

1. **Central RoleManager Contract**:
   - Maintains a global registry of roles across the protocol
   - Acts as the source of truth for role assignments
   - Provides helper functions for role checks

2. **Contract-Level Role Enforcement**:
   - Each contract checks role permissions by querying the central RoleManager
   - Caching mechanisms can be used to reduce gas costs for frequent role checks

### Technical Implementation

We recommend using Solady's OwnableRoles or EnumerableRoles library for several reasons:

1. **Gas Efficiency**: Highly optimized assembly-based implementation
2. **Bitmap Representation**: Efficient storage using uint256 bitmaps (OwnableRoles) or enumerable sets (EnumerableRoles)
3. **Flexibility**: Supports both owner + roles or purely role-based permission systems
4. **Security**: Well-audited, battle-tested implementation
5. **Compatibility**: Works with existing protocol architecture

#### OwnableRoles vs EnumerableRoles

For the central RoleManager, we recommend using **OwnableRoles** because:
- Efficient bitmap representation for roles (up to 256 roles in a single uint256)
- Combined ownership and role-based permissions
- Gas-optimized implementation with assembly

For contracts that need to enumerate role holders (like KYC management), we could use **EnumerableRoles** because:
- Provides functions to list all addresses with a specific role
- Useful for operational functions where listing role holders is important

### Gas Optimization Strategies

1. **Role Grouping**: Group related permissions into single roles
2. **Bitmap Representation**: Efficiently store roles using uint256 bitmaps
3. **Local Caching**: Cache role checks in memory during complex operations
4. **Event-Based Updates**: Use events for off-chain tracking of role changes

### Implementation Code Pattern

```solidity
// Simplified example of the RoleManager contract
contract RoleManager is OwnableRoles {
    // Root role
    uint256 public constant PROTOCOL_ADMIN = _ROLE_0;

    // Functional roles
    uint256 public constant REGISTRY_ADMIN = _ROLE_1;
    uint256 public constant STRATEGY_ADMIN = _ROLE_2;
    uint256 public constant KYC_ADMIN = _ROLE_3;
    uint256 public constant REPORTER_ADMIN = _ROLE_4;
    uint256 public constant SUBSCRIPTION_ADMIN = _ROLE_5;
    uint256 public constant WITHDRAWAL_ADMIN = _ROLE_6;

    // Operational roles
    uint256 public constant STRATEGY_MANAGER = _ROLE_7;
    uint256 public constant KYC_OPERATOR = _ROLE_8;
    uint256 public constant DATA_PROVIDER = _ROLE_9;

    constructor() {
        _initializeOwner(msg.sender);
        // Grant PROTOCOL_ADMIN to deployer
        _grantRoles(msg.sender, PROTOCOL_ADMIN);
    }

    // Function to grant roles (only callable by owner or PROTOCOL_ADMIN)
    function grantRole(address user, uint256 role) public payable onlyOwnerOrRoles(PROTOCOL_ADMIN) {
        // Special case for operational roles that are managed by their functional admins
        if (role == KYC_OPERATOR) {
            _checkRoles(KYC_ADMIN);
        } else if (role == DATA_PROVIDER) {
            _checkRoles(REPORTER_ADMIN);
        } else if (role == STRATEGY_MANAGER) {
            _checkRoles(STRATEGY_ADMIN);
        }

        _grantRoles(user, role);
    }

    // Function to revoke roles (same permission model as grantRole)
    function revokeRole(address user, uint256 role) public payable {
        // Special case for operational roles that are managed by their functional admins
        if (role == KYC_OPERATOR) {
            _checkRoles(KYC_ADMIN);
        } else if (role == DATA_PROVIDER) {
            _checkRoles(REPORTER_ADMIN);
        } else if (role == STRATEGY_MANAGER) {
            _checkRoles(STRATEGY_ADMIN);
        } else {
            _checkRolesOrOwner(PROTOCOL_ADMIN);
        }

        _removeRoles(user, role);
    }

    // Check if an address has a specific role
    function hasRole(address user, uint256 role) public view returns (bool) {
        return hasAnyRole(user, role);
    }

    // Check if an address is authorized for a contract operation
    function isAuthorized(address user, bytes4 selector) public view returns (bool) {
        // Map function selectors to required roles
        // Implementation would contain mappings of function selectors to roles
        // This is a simplified example
        return true;
    }
}
```

## Next Steps

1. Implement the RoleManager contract based on Solady's OwnableRoles
2. Modify existing contracts to integrate with the RoleManager
3. Create comprehensive tests for role management
4. Consider implementing time-locked role transitions for critical roles
5. Develop a multi-signature scheme for PROTOCOL_ADMIN operations