# Queued Withdrawal System: Technical Design Document

## 1. Introduction

This document outlines the technical design for a queued withdrawal system. This system allows users to request withdrawals of their funds, which are then processed by a strategy manager. This approach is necessary when funds are not directly and immediately accessible for withdrawal by the user, such as when they are locked in strategies, managed externally, or require manual intervention for security reasons. It provides a controlled and transparent process for users to access their assets.

## 2. Goals

*   **Controlled Withdrawals:** Prevent direct, immediate withdrawals by users. All withdrawals must be requested and then explicitly processed.
*   **User Experience:** Provide users with a clear way to request withdrawals and track their status.
*   **Managerial Oversight:** Enable strategy managers to view, manage, and process withdrawal requests efficiently.
*   **Transparency:** Maintain a record of all withdrawal requests and their lifecycle.
*   **Security:** Ensure the withdrawal process is secure and prevents unauthorized fund movements.
*   **Atomicity (Desirable):** Ensure that state changes related to withdrawal requests are consistent with actual fund movements where possible.

## 3. Non-Goals

*   Instantaneous withdrawal processing.
*   Automated market making or liquidation to free up funds (this system focuses on the request and processing queue, not the underlying fund management).
*   Direct on-chain interaction for the *request* phase (requests might be off-chain, while processing might involve on-chain transactions).

## 4. Actors

*   **User:** An individual or entity woorden funds in the system and wishes to withdraw them.
*   **Strategy Manager:** An authorized entity responsible for reviewing and processing withdrawal requests. This could be a person, a multi-sig group, or an automated system with appropriate permissions.
*   **System/Platform:** The backend infrastructure, potentially including smart contracts and databases, that facilitates the withdrawal request and processing flow.

## 5. Core Entities / Data Structures

### 5.1. WithdrawalRequest

This is the central entity representing a user's intent to withdraw funds.

| Field             | Type          | Description                                                                 | Example                              |
|-------------------|---------------|-----------------------------------------------------------------------------|--------------------------------------|
| `requestId`       | UUID/String   | Unique identifier for the withdrawal request.                               | `wth_req_abc123xyz789`               |
| `userId`          | String/Address| Identifier of the user making the request.                                  | `0xUserAddress123...` / `user_id_42` |
| `strategyId`      | String        | Identifier of the strategy from which funds are to be withdrawn.            | `strategy_yield_farm_v1`             |
| `assetAddress`    | Address/String| Address of the token/asset to be withdrawn.                                 | `0xTokenAddressABC...`               |
| `amount`          | BigNumber/Decimal | Amount of the asset requested for withdrawal (in smallest denomination).    | `1000000000000000000` (1 token)      |
| `recipientAddress`| Address       | The address where the user wants to receive the withdrawn funds.            | `0xUserDestinationAddress...`        |
| `status`          | Enum          | Current status of the request.                                              | `PENDING`                            |
| `userSignature`   | String        | Cryptographic signature of core request details by the user.                | `0xSignature...`                     |
| `nonce`           | Uint256/String| Unique, user-specific number to prevent replay attacks for signatures.      | `123`                                |
| `requestedAt`     | Timestamp     | Timestamp when the request was created.                                     | `2023-10-27T10:00:00Z`               |
| `updatedAt`       | Timestamp     | Timestamp when the request was last updated.                                | `2023-10-27T10:05:00Z`               |
| `processedAt`     | Timestamp     | Timestamp when the request was fully processed (completed or failed).       | `2023-10-28T14:30:00Z` (optional)    |
| `processingTxHash`| String        | Transaction hash of the on-chain processing step (if applicable).           | `0xProcessTxHash...` (optional)      |
| `completionTxHash`| String        | Transaction hash of the final on-chain withdrawal (if applicable).          | `0xWithdrawTxHash...` (optional)     |
| `failureReason`   | String        | Reason for failure, if the request status is `FAILED` or `CANCELLED_BY_MANAGER`. | `Insufficient unlocked funds` (optional) |
| `notes`           | String        | Optional notes by the user or manager.                                      | `Priority withdrawal` (optional)     |

**Possible `status` values:**

*   `PENDING`: User has submitted the request; awaiting manager review.
*   `APPROVED`: Manager has approved the request; awaiting processing (e.g., funds being moved or unbonded).
*   `PROCESSING`: The withdrawal is actively being processed (e.g., funds are being sent).
*   `COMPLETED`: The withdrawal was successfully processed, and funds have been sent to the user.
*   `FAILED`: The withdrawal attempt failed.
*   `CANCELLED_BY_USER`: The user cancelled the request (if allowed).
*   `CANCELLED_BY_MANAGER`: The manager rejected or cancelled the request.

## 6. Workflows / User Stories

### 6.1. User Requests a Withdrawal

1.  **Trigger:** User initiates a withdrawal request via a UI or API.
2.  **Input:** User provides `strategyId`, `assetAddress`, `amount`, `recipientAddress`, and a `nonce` (e.g., incrementing counter specific to the user and strategy, or a sufficiently random unique ID).
3.  **User Action (Client-Side):**
    a.  The user's client (e.g., wallet or frontend) constructs a message containing the core withdrawal details: `userId`, `strategyId`, `assetAddress`, `amount`, `recipientAddress`, `nonce`.
    b.  The user signs this message with their private key.
4.  **System Actions (Backend Submission):**
    a.  The client submits the withdrawal details along with the `userSignature` to the backend.
    b.  Validate inputs (e.g., user has sufficient balance in the strategy, valid asset, valid amount, valid signature format, nonce hasn't been used for this user).
    c.  Verify the `userSignature` against the provided details and the `userId`. If invalid, reject the request.
    d.  Create a new `WithdrawalRequest` record with `status: PENDING`.
    e.  Store `requestId`, `userId`, `strategyId`, `assetAddress`, `amount`, `recipientAddress`, `nonce`, `userSignature`, `requestedAt`, `updatedAt`.
    f.  (Optional) Lock the requested amount in the user's balance within the strategy to prevent double-spending *after* signature verification.
5.  **Output:** System returns the `requestId` to the user.
6.  **Notification:** (Optional) Notify the user that their request has been submitted.

### 6.2. User Views Their Withdrawal Requests

1.  **Trigger:** User accesses their withdrawal history/status page.
2.  **Input:** `userId`. Optional filters for `status`, `assetAddress`.
3.  **System Actions:** Query the datastore for `WithdrawalRequest` records matching the `userId` and filters.
4.  **Output:** Display a list of withdrawal requests with their details (especially `requestId`, `assetAddress`, `amount`, `status`, `requestedAt`).

### 6.3. User Cancels a Pending Withdrawal Request (Optional Feature)

1.  **Trigger:** User chooses to cancel an existing request.
2.  **Input:** `userId`, `requestId`.
3.  **System Actions:**
    a.  Verify that the request belongs to the user and its `status` is `PENDING` (or other cancellable states).
    b.  Update the `WithdrawalRequest` `status` to `CANCELLED_BY_USER`.
    c.  Set `updatedAt`.
    d.  (Optional) If funds were locked, unlock them.
4.  **Output:** Confirmation of cancellation.
5.  **Notification:** (Optional) Notify the user of the cancellation.

### 6.4. Strategy Manager Views Pending/All Withdrawal Requests

1.  **Trigger:** Manager accesses the withdrawal management dashboard.
2.  **Input:** Filters (e.g., `status: PENDING`, `status: APPROVED`, `strategyId`, `assetAddress`), sorting options (e.g., by `requestedAt`), pagination.
3.  **System Actions:** Query the datastore for `WithdrawalRequest` records matching the filters.
4.  **Output:** Display a list/table of withdrawal requests with relevant details for manager review.

### 6.5. Strategy Manager Approves/Rejects a Withdrawal Request

1.  **Trigger:** Manager decides to act on a `PENDING` request.
2.  **Input:** `requestId`, action (`APPROVE` or `REJECT`), `failureReason` (if rejecting).
3.  **System Actions (Approve):**
    a.  Verify manager permissions.
    b.  Update `WithdrawalRequest` `status` to `APPROVED`.
    c.  Set `updatedAt`.
    d.  (Optional) Add notes.
4.  **System Actions (Reject):**
    a.  Verify manager permissions.
    b.  Update `WithdrawalRequest` `status` to `CANCELLED_BY_MANAGER`.
    c.  Store `failureReason`.
    d.  Set `updatedAt`.
    e.  (Optional) If funds were locked, unlock them.
5.  **Output:** Confirmation of action.
6.  **Notification:** (Optional) Notify user of status change.

### 6.6. Strategy Manager Processes an Approved Withdrawal Request

1.  **Trigger:** Manager initiates the actual fund movement for an `APPROVED` request. This might be a manual or semi-automated process.
2.  **Input:** `requestId`. The system retrieves the full `WithdrawalRequest` details including `userId`, `assetAddress`, `amount`, `recipientAddress`, `nonce`, and `userSignature`.
3.  **System Actions (Pre-Processing):**
    a.  Manager verifies funds are available/unlocked from the strategy.
    b.  Update `WithdrawalRequest` `status` to `PROCESSING`.
    c.  Set `updatedAt`.
    d.  (Optional) Record `processingTxHash` if there's an intermediate on-chain step (e.g., moving funds from a vault to a hot wallet).
4.  **External Action:** Manager executes the fund transfer to the user's `recipientAddress`. This could involve:
    *   Signing a transaction from a cold wallet.
    *   Interacting with an exchange.
    *   Orchestrating an on-chain transaction via a smart contract. **Crucially, if a smart contract is involved in dispensing funds, it MUST:**
        *   Receive the original signed message components (`userId`, `strategyId`, `assetAddress`, `amount`, `recipientAddress`, `nonce`) and the `userSignature`.
        *   Reconstruct the message hash exactly as the user signed it.
        *   Use `ecrecover` (or an equivalent mechanism) to derive the signer's address from the message hash and `userSignature`.
        *   Verify that the recovered signer address matches the `userId` of the withdrawal request.
        *   Verify that the `nonce` (or a hash of the unique request details) has not been processed before to prevent replay attacks.
        *   Only upon successful verification of the signature and nonce, the contract should proceed with the fund transfer.
5.  **System Actions (Post-Processing - Success):**
    a.  Once external transfer is confirmed successful:
    b.  Update `WithdrawalRequest` `status` to `COMPLETED`.
    c.  Store `completionTxHash` (if applicable).
    d.  Set `processedAt`, `updatedAt`.
6.  **System Actions (Post-Processing - Failure):**
    a.  If external transfer fails:
    b.  Update `WithdrawalRequest` `status` to `FAILED`.
    c.  Store `failureReason`.
    d.  Set `processedAt`, `updatedAt`.
    e.  (Optional) The request might be retried or revert to `APPROVED` or `PENDING` for further investigation.
7.  **Output:** Confirmation of processing status.
8.  **Notification:** (Optional) Notify user of `COMPLETED` or `FAILED` status, including `completionTxHash` or `failureReason`.

### 6.7. Batch Processing (Optional)

Strategy managers might process multiple approved requests together, especially if they involve the same asset or can be batched into a single on-chain transaction to save fees. The system should allow managers to select multiple requests and update their statuses accordingly.

## 7. API Design (High-Level)

These endpoints assume a RESTful or gRPC-style API. Authentication and authorization are required for all endpoints.

### User-Facing Endpoints:

*   **`POST /withdrawals/requests`**
    *   **Body:** `{ userId, strategyId, assetAddress, amount, recipientAddress, notes? }`
    *   **Response (Success 201):** `{ requestId, status, requestedAt, ... }`
    *   **Description:** User submits a new withdrawal request.

*   **`GET /withdrawals/requests`**
    *   **Query Params:** `userId`, `status?`, `assetAddress?`, `page?`, `limit?`
    *   **Response (Success 200):** `[{ requestId, assetAddress, amount, status, requestedAt, ... }]`
    *   **Description:** User lists their withdrawal requests.

*   **`GET /withdrawals/requests/{requestId}`**
    *   **Response (Success 200):** `{ requestId, userId, assetAddress, amount, status, ...details }`
    *   **Description:** User gets details of a specific withdrawal request.

*   **`POST /withdrawals/requests/{requestId}/cancel`** (If cancellation by user is allowed)
    *   **Body:** `{ userId }`
    *   **Response (Success 200):** `{ requestId, status, ... }`
    *   **Description:** User cancels a pending withdrawal request.

### Manager-Facing Endpoints:

*   **`GET /manager/withdrawals/requests`**
    *   **Query Params:** `status?`, `strategyId?`, `assetAddress?`, `userId?`, `page?`, `limit?`, `sortBy?`, `sortOrder?`
    *   **Response (Success 200):** `[{ requestId, userId, assetAddress, amount, status, requestedAt, ... }]`
    *   **Description:** Manager lists withdrawal requests with advanced filtering and sorting.

*   **`GET /manager/withdrawals/requests/{requestId}`**
    *   **Response (Success 200):** `{ requestId, userId, assetAddress, amount, status, ...details }`
    *   **Description:** Manager gets details of a specific withdrawal request.

*   **`POST /manager/withdrawals/requests/{requestId}/approve`**
    *   **Body:** `{ notes? }`
    *   **Response (Success 200):** `{ requestId, status, ... }`
    *   **Description:** Manager approves a pending request.

*   **`POST /manager/withdrawals/requests/{requestId}/reject`**
    *   **Body:** `{ failureReason, notes? }`
    *   **Response (Success 200):** `{ requestId, status, failureReason, ... }`
    *   **Description:** Manager rejects a pending request.

*   **`POST /manager/withdrawals/requests/{requestId}/process`**
    *   **Body:** `{ status: ("PROCESSING" | "COMPLETED" | "FAILED"), processingTxHash?, completionTxHash?, failureReason?, notes? }`
    *   **Response (Success 200):** `{ requestId, status, ... }`
    *   **Description:** Manager updates the status of a request during processing (e.g., sets to `PROCESSING`, then later `COMPLETED` or `FAILED`). This endpoint allows flexibility in marking intermediate and final states.

## 8. Data Storage

*   A relational database (e.g., PostgreSQL) or a NoSQL database (e.g., MongoDB) can be used to store `WithdrawalRequest` records.
*   Ensure appropriate indexing on fields like `userId`, `status`, `assetAddress`, `strategyId`, and `requestedAt` for efficient querying.

## 9. Security Considerations

*   **Authentication & Authorization:**
    *   Robust authentication for users and managers.
    *   Role-based access control (RBAC) to ensure only authorized managers can approve/process requests.
    *   Users can only view/cancel their own requests.
*   **Input Validation:** Rigorously validate all inputs to prevent injection attacks, invalid data, and ensure amounts are within permissible limits.
*   **User Signature Verification:** All withdrawal requests must be cryptographically signed by the user over a well-defined message structure including a nonce. This signature must be verifiable by the backend system upon submission and, most critically, by any smart contract involved in dispensing funds. This ensures that the request originated from the legitimate user and that the manager is merely executing a user-authorized action.
*   **Replay Protection:** Utilize a unique, user-specific nonce for each withdrawal request that is part of the signed message. The system (especially any on-chain component) must track used nonces for each user to prevent a signed message from being replayed.
*   **Idempotency:** For operations like request submission or status updates, consider designing them to be idempotent to prevent issues from retries.
*   **Race Conditions:**
    *   When locking funds or updating status, use database transactions or optimistic locking to prevent race conditions.
    *   Ensure that a request cannot be processed multiple times.
*   **Audit Trails:** Maintain a comprehensive audit log of all actions performed on withdrawal requests, including who performed the action and when.
*   **Protection of Sensitive Data:** `recipientAddress` and transaction hashes should be handled securely.
*   **Manager Wallet Security:** The process for managers to execute actual withdrawals (signing transactions) must be highly secure (e.g., multi-sig wallets, hardware wallets, secure operational procedures).
*   **DoS Prevention:** Implement rate limiting on API endpoints.

## 10. Scalability and Performance

*   **Database Optimization:** Proper indexing, query optimization, and potentially read replicas for the database.
*   **Asynchronous Processing:** For notifications or less critical updates, use message queues to offload work from the main request-response cycle.
*   **Horizontal Scaling:** Design API servers to be stateless for easier horizontal scaling.
*   **Efficient Querying:** Design queries for manager dashboards to be efficient, especially with large numbers of requests. Consider archiving old, completed requests.

## 11. User Interface (UI) Considerations

*   **User Dashboard:**
    *   Clear display of requested withdrawals and their current status.
    *   Easy way to initiate a new withdrawal request.
    *   Visible `requestId` for tracking.
    *   Details like `asset`, `amount`, `recipientAddress`, `timestamp`.
    *   Option to cancel (if implemented).
*   **Manager Dashboard:**
    *   Table view of withdrawal requests with sorting and filtering (by status, date, user, asset, etc.).
    *   Clear calls to action for `Approve`, `Reject`, `Process`.
    *   Ability to view request details and add notes.
    *   Batch operation capabilities.
    *   Summary statistics (e.g., total pending volume).

## 12. Future Considerations / Enhancements

*   **User Notifications:** Email, SMS, or in-app notifications for status changes (e.g., `REQUESTED`, `APPROVED`, `COMPLETED`, `FAILED`).
*   **Priority Queue:** Implement a priority system for withdrawals (e.g., based on user tier, fees paid).
*   **Withdrawal Fees:** Integrate a fee structure for withdrawals.
*   **Estimated Processing Time:** Provide users with an estimated time for their withdrawal to be processed.
*   **Partial Fills:** Allow managers to partially fill a withdrawal request if full amount is not immediately available.
*   **Automated Processing Rules:** For certain conditions (e.g., small amounts, trusted users), allow for automated approval or even processing up to certain thresholds, with appropriate risk controls.
*   **Integration with Custody Solutions:** Direct API integration with custodial services for more streamlined processing by managers.

This design document provides a foundational structure. Specific implementation details will depend on the existing platform architecture, chosen technologies, and precise business requirements.