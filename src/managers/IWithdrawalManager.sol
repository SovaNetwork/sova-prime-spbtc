// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IWithdrawalManager
 * @notice Interface for managing withdrawal requests and withdrawal periods
 * @dev Handles the queuing, approval, and execution of withdrawals
 */
interface IWithdrawalManager {
    // Structs
    struct WithdrawalRequest {
        uint256 id;               // Unique identifier for the withdrawal request
        address user;             // User requesting the withdrawal
        uint256 assets;           // Amount of assets requested for withdrawal
        uint256 shares;           // Amount of shares to be burned
        uint256 requestTime;      // Timestamp when request was made
        bool approved;            // Whether withdrawal has been approved
        bool executed;            // Whether withdrawal has been executed
    }

    struct WithdrawalPeriod {
        uint256 id;               // Unique identifier for the withdrawal period
        uint256 startTime;        // Start timestamp of the withdrawal period
        uint256 endTime;          // End timestamp of the withdrawal period
        bytes32 merkleRoot;       // Merkle root of approved withdrawals
        uint256 totalAssets;      // Total assets earmarked for this period
        uint256 withdrawnAssets;  // Total assets withdrawn so far
        bool active;              // Whether this period is currently active
    }

    // Events
    event WithdrawalRequested(uint256 indexed requestId, address indexed user, uint256 assets, uint256 shares);
    event WithdrawalPeriodOpened(uint256 indexed periodId, uint256 startTime, uint256 endTime, bytes32 merkleRoot, uint256 totalAssets);
    event WithdrawalExecuted(uint256 indexed requestId, address indexed user, uint256 assets);
    event WithdrawalPeriodClosed(uint256 indexed periodId, uint256 endTime, uint256 totalWithdrawn);
    event WithdrawalsApproved(uint256 indexed periodId, uint256[] requestIds);

    // Errors
    error InvalidAddress();
    error InvalidWithdrawalRequest();
    error WithdrawalPeriodInactive();
    error WithdrawalPeriodActive();
    error WithdrawalUnauthorized();
    error InvalidMerkleProof();
    error WithdrawalAlreadyExecuted();
    error InsufficientFunds();
    error InvalidAmount();

    // User functions
    function requestWithdrawal(address user, uint256 assets, uint256 shares) external returns (uint256 requestId);
    function executeWithdrawal(uint256 requestId, bytes32[] calldata merkleProof) external returns (bool success);

    // Admin functions
    function openWithdrawalPeriod(uint256 duration, bytes32 merkleRoot, uint256 totalAssets) external returns (uint256 periodId);
    function closeWithdrawalPeriod() external;
    function approveWithdrawals(uint256[] calldata requestIds) external;

    // View functions
    function getWithdrawalRequest(uint256 requestId) external view returns (WithdrawalRequest memory request);
    function getCurrentWithdrawalPeriod() external view returns (WithdrawalPeriod memory period);
    function getPendingWithdrawalRequests(address user) external view returns (WithdrawalRequest[] memory requests);
    function isValidWithdrawal(uint256 requestId, bytes32[] calldata merkleProof) external view returns (bool valid);
}