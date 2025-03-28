# Contract Information Required for Protocol Integration Flows

This document outlines the contract information required for the integration flows with the tRWA protocol.

## Flow 1: User Registration and Transfer Approval

### Required Contract Components:
1. **TransferApproval Contract**
   - **Address**: The deployed TransferApproval contract address
   - **Functions used**:
     - `approveKyc(address _user)`: Used by admin to approve a user for transfers
     - `batchApproveKyc(address[] memory _users)`: For approving multiple users at once

### Data Requirements:
1. **User Information**:
   - User's wallet address for KYC approval

### Workflow Details:
1. User submits wallet address through website registration
2. Admin retrieves pending addresses from the queue
3. Admin calls `approveKyc(address _user)` or `batchApproveKyc(address[] memory _users)` to approve the user
4. System records KYC approval status through the `KycApproved` event

### Authorization Requirements:
- **Admin Role**: The address calling the approval function must have the admin or compliance officer role in the TransferApproval contract

## Flow 2: tRWA Contract Deployment

### Required Contract Components:
1. **tRWAFactory Contract**
   - **Address**: The deployed tRWAFactory contract address
   - **Functions used**:
     - `deployToken(string memory _name, string memory _symbol, address _oracle, address _subscriptionManager, address _underlyingAsset, address _transferApproval)`: Used to deploy a new token

2. **Pre-approved Components**:
   - Oracle contract address (must be approved in the factory)
   - Subscription manager contract address (must be approved in the factory)
   - Underlying asset contract address (must be approved in the factory)
   - TransferApproval contract address (must be approved in the factory or can be 0 if not needed)

### Data Requirements:
1. **Token Configuration**:
   - Token name
   - Token symbol
   - Oracle address to use for price updates
   - Subscription manager address for handling deposits
   - Underlying asset address (ERC20 token used for deposits)
   - Transfer approval address (can be address(0) if not using KYC)

2. **Initial Token Parameters**:
   - Initial NAV (Net Asset Value) per token

### Workflow Details:
1. Admin configures token parameters
2. Admin calls `deployToken()` on the tRWAFactory contract
3. System deploys a new tRWA contract with the provided configuration
4. System records token deployment through the `TokenDeployed` event

### Authorization Requirements:
- **Owner Role**: Only the owner of the tRWAFactory can deploy new tokens

## Flow 3: Approved User Deposit

### Required Contract Components:
1. **tRWA Contract**
   - **Address**: The deployed tRWA token contract address
   - **Functions used**:
     - `deposit(uint256 assets, address receiver)`: For direct deposits (only callable by subscription role)

2. **SubscriptionModule Contract** (one of the following types):
   - **BaseSubscriptionModule**: For simple 1:1 deposits without approval
   - **ApprovalSubscriptionModule**: For deposits requiring admin approval
   - **CappedApprovalSubscriptionModule**: For deposits with a maximum cap
   - **Functions used**:
     - `deposit(uint256 _amount)`: Used by user to initiate deposit
     - `approveSubscription(address _subscriber, uint256 _index)`: Used by admin to approve pending deposits (for ApprovalSubscriptionModule)
     - `approveAllSubscriptions(address _subscriber)`: For approving all pending deposits of a user (for ApprovalSubscriptionModule)

3. **TransferApproval Contract**
   - Must have previously approved user for KYC (see Flow 1)

### Data Requirements:
1. **Deposit Information**:
   - Amount of underlying assets to deposit
   - User's wallet address (must have been approved for KYC)

2. **Underlying Asset**:
   - User must have sufficient balance of the underlying asset
   - User must have approved the subscription module contract to spend their tokens

### Workflow Details:
For direct deposit (if user has subscription role):
1. User approves the tRWA contract to spend their underlying assets
2. User calls `deposit(uint256 assets, address receiver)` on the tRWA contract

For deposit through Approval Subscription Module:
1. User approves the subscription module to spend their underlying assets
2. User calls `deposit(uint256 _amount)` on the subscription module
3. Deposit is added to pending deposits queue
4. Admin approves the deposit by calling `approveSubscription(address _subscriber, uint256 _index)`
5. System mints tRWA tokens to the user and records the deposit through events

### Authorization Requirements:
- **KYC Approval**: User must be approved in the TransferApproval contract
- **Subscription Role**: For direct deposits to the tRWA contract, the caller must have the SUBSCRIPTION_ROLE
- **Admin Role**: For approving deposits in the ApprovalSubscriptionModule

### Additional Notes:
- Deposits through the subscription module require admin approval before tokens are minted
- After approval, tokens are minted and sent to the user's wallet
- The deposit amount is added to the `pendingDeposits` pool in the tRWA contract
- A manager with the MANAGER_ROLE can later withdraw these pending deposits