// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {GatedMintRWA} from "../token/GatedMintRWA.sol";

/**
 * @title GatedMintEscrow
 * @notice Contract to hold assets during the two-phase deposit process
 * @dev Deployed alongside each GatedMintRWA token to manage pending deposits
 */
contract GatedMintEscrow {
    // Custom errors
    error Unauthorized();
    error DepositNotFound();
    error DepositNotPending();
    error InvalidAddress();

    // Enum to track the deposit state
    enum DepositState {
        PENDING,
        ACCEPTED,
        REFUNDED
    }

    struct PendingDeposit {
        address depositor;      // Address that initiated the deposit
        address recipient;      // Address that will receive shares if approved
        uint256 assetAmount;    // Amount of assets deposited
        uint256 expirationTime; // Timestamp after which deposit can be reclaimed
        DepositState state;     // Current state of the deposit
    }

    // Immutable contract references
    address public immutable token;     // The GatedMintRWA token
    address public immutable asset;     // The underlying asset (e.g. USDC)
    address public immutable strategy;  // The strategy contract

    // Storage for deposits
    mapping(bytes32 => PendingDeposit) public pendingDeposits;

    // Accounting for total amounts
    uint256 public totalPendingAssets;
    mapping(address => uint256) public userPendingAssets;

    // Events
    event DepositReceived(
        bytes32 indexed depositId,
        address indexed depositor,
        address indexed recipient,
        uint256 assets,
        uint256 expirationTime
    );
    event DepositAccepted(bytes32 indexed depositId, address indexed recipient, uint256 assets);
    event DepositRefunded(bytes32 indexed depositId, address indexed depositor, uint256 assets);
    event DepositReclaimed(bytes32 indexed depositId, address indexed depositor, uint256 assets);

    /**
     * @notice Constructor
     * @param _token The GatedMintRWA token address
     * @param _asset The underlying asset address
     * @param _strategy The strategy contract address
     */
    constructor(
        address _token,
        address _asset,
        address _strategy
    ) {
        if (_token == address(0)) revert InvalidAddress();
        if (_asset == address(0)) revert InvalidAddress();
        if (_strategy == address(0)) revert InvalidAddress();

        token = _token;
        asset = _asset;
        strategy = _strategy;
    }

    /**
     * @notice Receive a deposit from the GatedMintRWA token
     * @param depositId Unique identifier for the deposit
     * @param depositor Address that initiated the deposit
     * @param recipient Address that will receive shares if approved
     * @param amount Amount of assets deposited
     * @param expirationTime Time after which deposit can be reclaimed
     */
    function receiveDeposit(
        bytes32 depositId,
        address depositor,
        address recipient,
        uint256 amount,
        uint256 expirationTime
    ) external {
        // Only GatedMintRWA token can call this function
        if (msg.sender != token) revert Unauthorized();

        // Store the deposit data
        pendingDeposits[depositId] = PendingDeposit({
            depositor: depositor,
            recipient: recipient,
            assetAmount: amount,
            expirationTime: expirationTime,
            state: DepositState.PENDING
        });

        // Update accounting
        totalPendingAssets += amount;
        userPendingAssets[depositor] += amount;

        emit DepositReceived(depositId, depositor, recipient, amount, expirationTime);
    }

    /**
     * @notice Accept a pending deposit
     * @param depositId The deposit ID to accept
     */
    function acceptDeposit(bytes32 depositId) external {
        // Only strategy can call this function
        if (msg.sender != strategy) revert Unauthorized();

        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();

        // Mark as accepted
        deposit.state = DepositState.ACCEPTED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Transfer assets to the strategy
        SafeTransferLib.safeTransfer(asset, strategy, deposit.assetAmount);

        // Tell the GatedMintRWA token to mint shares
        GatedMintRWA(token).mintShares(deposit.recipient, deposit.assetAmount);

        emit DepositAccepted(depositId, deposit.recipient, deposit.assetAmount);
    }

    /**
     * @notice Refund a pending deposit
     * @param depositId The deposit ID to refund
     */
    function refundDeposit(bytes32 depositId) external {
        // Only strategy can call this function
        if (msg.sender != strategy) revert Unauthorized();

        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();

        // Mark as refunded
        deposit.state = DepositState.REFUNDED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Return assets to the depositor
        SafeTransferLib.safeTransfer(asset, deposit.depositor, deposit.assetAmount);

        emit DepositRefunded(depositId, deposit.depositor, deposit.assetAmount);
    }

    /**
     * @notice Allow a user to reclaim their expired deposit
     * @param depositId The deposit ID to reclaim
     */
    function reclaimDeposit(bytes32 depositId) external {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();
        if (msg.sender != deposit.depositor) revert Unauthorized();
        if (block.timestamp < deposit.expirationTime) revert Unauthorized();

        // Mark as refunded
        deposit.state = DepositState.REFUNDED;

        // Update accounting
        totalPendingAssets -= deposit.assetAmount;
        userPendingAssets[deposit.depositor] -= deposit.assetAmount;

        // Return assets to the depositor
        SafeTransferLib.safeTransfer(asset, deposit.depositor, deposit.assetAmount);

        emit DepositReclaimed(depositId, deposit.depositor, deposit.assetAmount);
    }

    /**
     * @notice Get the details of a pending deposit
     * @param depositId The deposit ID
     * @return The deposit details
     */
    function getPendingDeposit(bytes32 depositId) external view returns (PendingDeposit memory) {
        return pendingDeposits[depositId];
    }
}