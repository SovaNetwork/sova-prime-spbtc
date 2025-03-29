// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ItRWAHook} from "../interfaces/ItRWAHook.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";

/**
 * @title TransferApprovalHook
 * @notice Hook that provides transfer approval checks for tRWA
 * @dev This is a replacement for the direct transfer approval in tRWA
 */
contract TransferApprovalHook is ItRWAHook, OwnableRoles {
    uint256 public constant APPROVER_ROLE = 1 << 0;

    address public immutable tRWA;
    bool public enabled = true;

    // Events
    event TransferApproved(address indexed from, address indexed to, uint256 value);
    event TransferRejected(address indexed from, address indexed to, uint256 value, string reason);
    event StatusChanged(bool enabled);

    // Errors
    error Unauthorized();

    /**
     * @notice Contract constructor
     * @param _tRWA Address of the tRWA contract
     * @param _admin Admin address
     */
    constructor(address _tRWA, address _admin) {
        require(_tRWA != address(0), "Invalid tRWA address");
        require(_admin != address(0), "Invalid admin address");

        tRWA = _tRWA;
        _initializeOwner(_admin);
        _grantRoles(_admin, APPROVER_ROLE);
    }

    /**
     * @notice Toggle the enabled status of transfer approval
     * @param _enabled Whether the hook is enabled
     */
    function toggleEnabled(bool _enabled) external onlyOwnerOrRoles(APPROVER_ROLE) {
        enabled = _enabled;
        emit StatusChanged(_enabled);
    }

    /**
     * @notice Check if a transfer is allowed
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param value Amount of tokens being transferred
     * @return Whether the transfer is allowed
     */
    function beforeTransfer(address from, address to, uint256 value) external override returns (bool) {
        // Only allow calls from tRWA contract
        if (msg.sender != tRWA) revert Unauthorized();

        // Skip checks if disabled
        if (!enabled) return true;

        // Disallow transfers to zero address
        if (to == address(0)) {
            emit TransferRejected(from, to, value, "Transfer to zero address");
            revert ItRWA.TransferBlocked("Transfer to zero address");
        }

        // All other transfers are approved
        emit TransferApproved(from, to, value);
        return true;
    }

    // Required interface functions (not used)
    function beforeDeposit(address, uint256, address) external pure override returns (bool) { return true; }
    function beforeMint(address, uint256, address) external pure override returns (bool) { return true; }
    function beforeWithdraw(address, uint256, address, address) external pure override returns (bool) { return true; }
    function beforeRedeem(address, uint256, address, address) external pure override returns (bool) { return true; }
    function afterDeposit(address, uint256, address, uint256) external pure override {}
    function afterMint(address, uint256, address, uint256) external pure override {}
    function afterWithdraw(address, uint256, address, address, uint256) external pure override {}
    function afterRedeem(address, uint256, address, address, uint256) external pure override {}
    function afterTransfer(address, address, uint256) external pure override {}
}