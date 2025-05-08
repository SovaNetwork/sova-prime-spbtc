// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "../hooks/IHook.sol";
import {Registry} from "../registry/Registry.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {Conduit} from "../conduit/Conduit.sol";

/**
 * @title GatedMintRWA
 * @notice Extension of tRWA that implements a two-phase deposit process
 * @dev Deposits are first collected and stored pending approval; shares are only minted upon acceptance
 */
contract GatedMintRWA is tRWA {
    // Custom errors
    error DepositNotFound();
    error DepositNotPending();
    error DepositNotExpired();
    error NotDepositor();
    error InvalidExpirationPeriod();

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

    // Events
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

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Decimals of the asset token
     * @param strategy_ Strategy address
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint8 assetDecimals_,
        address strategy_
    ) tRWA(name_, symbol_, asset_, assetDecimals_, strategy_) {
        // depositExpirationPeriod initialized with default value (7 days)
    }

    /**
     * @notice Sets the period after which deposits expire and can be reclaimed
     * @param newExpirationPeriod New expiration period in seconds
     */
    function setDepositExpirationPeriod(uint256 newExpirationPeriod) external onlyStrategy {
        if (newExpirationPeriod == 0) revert InvalidExpirationPeriod();
        
        uint256 oldPeriod = depositExpirationPeriod;
        depositExpirationPeriod = newExpirationPeriod;
        
        emit DepositExpirationPeriodUpdated(oldPeriod, newExpirationPeriod);
    }

    /**
     * @notice Override of _deposit to store deposit info instead of minting immediately
     * @param by Address of the sender
     * @param to Address of the recipient
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares to mint (not used directly, only for hook compatibility)
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

    /**
     * @notice Accept a pending deposit, minting tokens to the recipient
     * @param depositId The unique identifier of the deposit to accept
     * @return True if successful
     */
    function acceptDeposit(bytes32 depositId) external onlyStrategy returns (bool) {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();
        
        _processDeposit(depositId, DepositState.ACCEPTED);
        
        // Transfer the assets to the strategy
        SafeTransferLib.safeTransfer(asset(), strategy, deposit.assetAmount);
        
        // Calculate shares based on current exchange rate
        uint256 shares = previewDeposit(deposit.assetAmount);
        
        // Mint shares to the recipient
        _mint(deposit.recipient, shares);
        
        emit DepositAccepted(depositId, deposit.recipient, deposit.assetAmount, shares);
        return true;
    }

    /**
     * @notice Refund a pending deposit, returning assets to the depositor
     * @param depositId The unique identifier of the deposit to refund
     * @return True if successful
     */
    function refundDeposit(bytes32 depositId) external onlyStrategy returns (bool) {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();
        
        _processDeposit(depositId, DepositState.REFUNDED);
        
        // Return assets to the depositor
        SafeTransferLib.safeTransfer(asset(), deposit.depositor, deposit.assetAmount);
        
        emit DepositRefunded(depositId, deposit.depositor, deposit.assetAmount);
        return true;
    }

    /**
     * @notice Allow a user to reclaim their expired deposit
     * @param depositId The unique identifier of the deposit to reclaim
     * @return True if successful
     */
    function reclaimDeposit(bytes32 depositId) external returns (bool) {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        if (deposit.depositor == address(0)) revert DepositNotFound();
        if (deposit.state != DepositState.PENDING) revert DepositNotPending();
        if (deposit.depositor != msg.sender) revert NotDepositor();
        if (block.timestamp < deposit.expirationTime) revert DepositNotExpired();
        
        _processDeposit(depositId, DepositState.REFUNDED);
        
        // Return assets to the depositor
        SafeTransferLib.safeTransfer(asset(), deposit.depositor, deposit.assetAmount);
        
        emit DepositReclaimed(depositId, deposit.depositor, deposit.assetAmount);
        return true;
    }

    /**
     * @notice Get all pending deposit IDs for a specific user
     * @param user The user address
     * @return Array of deposit IDs
     */
    function getUserPendingDeposits(address user) external view returns (bytes32[] memory) {
        bytes32[] memory userDeposits = new bytes32[](userDepositIds[user].length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < userDepositIds[user].length; i++) {
            bytes32 depositId = userDepositIds[user][i];
            if (pendingDeposits[depositId].state == DepositState.PENDING) {
                userDeposits[count] = depositId;
                count++;
            }
        }
        
        // Resize array to fit only pending deposits
        bytes32[] memory result = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = userDeposits[i];
        }
        
        return result;
    }

    /**
     * @notice Get details for a specific deposit
     * @param depositId The unique identifier of the deposit
     * @return The deposit details
     */
    function getDepositDetails(bytes32 depositId) external view returns (PendingDeposit memory) {
        return pendingDeposits[depositId];
    }

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
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            depositor,
            recipient,
            assets,
            block.timestamp,
            address(this)
        ));
    }

    /**
     * @notice Process deposit status updates
     * @param depositId The deposit ID to process
     * @param newState The new state (ACCEPTED or REFUNDED)
     */
    function _processDeposit(bytes32 depositId, DepositState newState) internal {
        PendingDeposit storage deposit = pendingDeposits[depositId];
        deposit.state = newState;
    }
}