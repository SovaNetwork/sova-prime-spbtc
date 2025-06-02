// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IHook} from "../hooks/IHook.sol";
import {IRegistry} from "../registry/IRegistry.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {Conduit} from "../conduit/Conduit.sol";
import {GatedMintEscrow} from "../strategy/GatedMintEscrow.sol";

/**
 * @title GatedMintRWA
 * @notice Extension of tRWA that implements a two-phase deposit process using an Escrow
 * @dev Deposits are first collected and stored in Escrow; shares are only minted upon acceptance
 */
contract GatedMintRWA is tRWA {
    // Custom errors
    error NotEscrow();
    error EscrowNotSet();
    error InvalidExpirationPeriod();
    error InvalidArrayLengths();

    uint256 private constant ONE = 1e18;

    // Deposit tracking (IDs only - Escrow has full state)
    bytes32[] public depositIds;
    mapping(address => bytes32[]) public userDepositIds;

    // Deposit expiration time (in seconds) - default to 7 days
    uint256 public depositExpirationPeriod = 7 days;
    uint256 public constant MAX_DEPOSIT_EXPIRATION_PERIOD = 30 days;

    // The escrow contract that holds assets and manages deposits
    address public immutable escrow;

    // Events
    event DepositPending(
        bytes32 indexed depositId,
        address indexed depositor,
        address indexed recipient,
        uint256 assets
    );

    event DepositExpirationPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    event BatchSharesMinted(
        bytes32[] depositIds,
        uint256 totalAssets,
        uint256 totalShares
    );

    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint8 assetDecimals_,
        address strategy_
    ) tRWA(name_, symbol_, asset_, assetDecimals_, strategy_) {
        // Deploy the GatedMintEscrow contract with this token as the controller
        escrow = address(new GatedMintEscrow(address(this), asset_, strategy_));
    }

    /**
     * @notice Sets the period after which deposits expire and can be reclaimed
     * @param newExpirationPeriod New expiration period in seconds
     */
    function setDepositExpirationPeriod(uint256 newExpirationPeriod) external onlyStrategy {
        if (newExpirationPeriod == 0) revert InvalidExpirationPeriod();
        if (newExpirationPeriod > MAX_DEPOSIT_EXPIRATION_PERIOD) revert InvalidExpirationPeriod();

        uint256 oldPeriod = depositExpirationPeriod;
        depositExpirationPeriod = newExpirationPeriod;

        emit DepositExpirationPeriodUpdated(oldPeriod, newExpirationPeriod);
    }

    /**
     * @notice Override of _deposit to store deposit info instead of minting immediately
     * @param by Address of the sender
     * @param to Address of the recipient
     * @param assets Amount of assets to deposit
     */
    function _deposit(
        address by,
        address to,
        uint256 assets,
        uint256 // shares
    ) internal override {
        // Run hooks (same as in tRWA)
        HookInfo[] storage opHooks = operationHooks[OP_DEPOSIT];
        for (uint i = 0; i < opHooks.length; i++) {
            IHook.HookOutput memory hookOutput = opHooks[i].hook.onBeforeDeposit(address(this), by, assets, to);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
            // Mark hook as having processed operations
            opHooks[i].hasProcessedOperations = true;
        }

        // Generate deposit ID
        bytes32 depositId = keccak256(abi.encodePacked(
            by,
            to,
            assets,
            block.timestamp,
            address(this)
        ));

        // Record the deposit ID for lookup
        depositIds.push(depositId);
        userDepositIds[by].push(depositId);

        // Transfer assets to escrow
        Conduit(
            IRegistry(RoleManaged(strategy).registry()).conduit()
        ).collectDeposit(asset(), by, escrow, assets);

        // Register the deposit with the escrow
        uint256 expTime = block.timestamp + depositExpirationPeriod;
        GatedMintEscrow(escrow).handleDepositReceived(depositId, by, to, assets, expTime);

        // Emit a custom event for the pending deposit
        emit DepositPending(depositId, by, to, assets);
    }

    /**
     * @notice Mint shares for an accepted deposit (called by Escrow)
     * @param recipient The recipient of shares
     * @param assetAmount The asset amount
     */
    function mintShares(address recipient, uint256 assetAmount) external {
        // Only escrow can call this
        if (msg.sender != escrow) revert NotEscrow();

        // Calculate shares based on current exchange rate
        uint256 shares = previewDeposit(assetAmount);

        // Mint shares to the recipient
        _mint(recipient, shares);
    }

    /**
     * @notice Mint shares for a batch of accepted deposits with equal share pricing
     * @param ids Array of deposit IDs being processed in this batch
     * @param recipients Array of recipient addresses aligned with ids
     * @param assetAmounts Array of asset amounts aligned with ids
     * @param totalAssets Total assets in the batch (sum of assetAmounts)
     */
    function batchMintShares(
        bytes32[] calldata ids,
        address[] calldata recipients,
        uint256[] calldata assetAmounts,
        uint256 totalAssets
    ) external {
        // Only escrow can call this
        if (msg.sender != escrow) revert NotEscrow();

        // Validate array lengths match
        if (ids.length != recipients.length || recipients.length != assetAmounts.length) {
            revert InvalidArrayLengths();
        }

        // Calculate total shares based on the sum of all assets in the batch
        // This ensures all deposits get the same exchange rate
        uint256 totalShares = previewDeposit(totalAssets);

        // Distribute shares proportionally to each recipient based on their contribution
        for (uint256 i = 0; i < recipients.length; i++) {
            // Calculate this recipient's share of the total using higher precision
            uint256 scaledShares = totalShares * ONE;
            uint256 recipientShares = (assetAmounts[i] * scaledShares / totalAssets) / ONE;

            // Mint shares to the recipient
            _mint(recipients[i], recipientShares);
        }

        emit BatchSharesMinted(ids, totalAssets, totalShares);
    }

    /**
     * @notice Get all pending deposit IDs for a specific user
     * @param user The user address
     * @return Array of deposit IDs that are still pending
     */
    function getUserPendingDeposits(address user) external view returns (bytes32[] memory) {
        bytes32[] memory userDeposits = new bytes32[](userDepositIds[user].length);
        uint256 count = 0;

        for (uint256 i = 0; i < userDepositIds[user].length; i++) {
            bytes32 depositId = userDepositIds[user][i];

            // Query the escrow for deposit status
            (, , , , uint8 state) = getDepositDetails(depositId);

            // Only include if state is PENDING (0)
            if (state == 0) { // 0 = PENDING in the DepositState enum
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
     * @notice Get details for a specific deposit (from Escrow)
     * @param depositId The unique identifier of the deposit
     * @return depositor The address that initiated the deposit
     * @return recipient The address that will receive shares if approved
     * @return assetAmount The amount of assets deposited
     * @return expirationTime The timestamp after which deposit can be reclaimed
     * @return state The current state of the deposit (0=PENDING, 1=ACCEPTED, 2=REFUNDED)
     */
    function getDepositDetails(bytes32 depositId) public view returns (
        address depositor,
        address recipient,
        uint256 assetAmount,
        uint256 expirationTime,
        uint8 state
    ) {
        GatedMintEscrow.PendingDeposit memory deposit = GatedMintEscrow(escrow).getPendingDeposit(depositId);
        return (
            deposit.depositor,
            deposit.recipient,
            deposit.assetAmount,
            deposit.expirationTime,
            uint8(deposit.state)
        );
    }
}