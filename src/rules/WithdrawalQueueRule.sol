// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "./BaseRules.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IWithdrawalManager} from "../managers/IWithdrawalManager.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title WithdrawalQueueRule
 * @notice Rule that redirects withdrawals to a withdrawal manager
 * @dev Implements the withdrawal queue pattern by replacing direct withdrawals with queued requests
 */
contract WithdrawalQueueRule is BaseRules, OwnableRoles {
    // Role constants
    uint256 public constant MANAGER_ROLE = 1 << 0;

    // Withdrawal manager contract
    IWithdrawalManager public withdrawalManager;

    // Bitmap of operations this rule applies to
    uint256 private constant RULE_BITMAP = 0x4; // Applies to withdrawals (0x4)

    // Errors
    error InvalidAddress();
    error InvalidWithdrawalManager();
    error Unauthorized();

    /**
     * @notice Constructor
     * @param _withdrawalManager Withdrawal manager address
     * @param _admin Admin address
     */
    constructor(address _withdrawalManager, address _admin) BaseRules("WithdrawalQueueRule") {
        if (_withdrawalManager == address(0)) revert InvalidAddress();
        if (_admin == address(0)) revert InvalidAddress();

        withdrawalManager = IWithdrawalManager(_withdrawalManager);
        _initializeOwner(_admin);
    }

    /**
     * @notice Update the withdrawal manager
     * @param _withdrawalManager New withdrawal manager address
     */
    function setWithdrawalManager(address _withdrawalManager) external onlyOwnerOrRoles(MANAGER_ROLE) {
        if (_withdrawalManager == address(0)) revert InvalidAddress();
        withdrawalManager = IWithdrawalManager(_withdrawalManager);
        emit WithdrawalManagerUpdated(_withdrawalManager);
    }

    /**
     * @notice Returns the bitmap of operations this rule applies to
     * @return Bitmap of operations (only withdrawals)
     */
    function appliesTo() external pure override returns (uint256) {
        return RULE_BITMAP;
    }

    /**
     * @notice Default implementation for deposit rule
     * @return Always approves deposits
     */
    function evaluateDeposit(
        address,
        address,
        uint256,
        address
    ) public override returns (RuleResult memory) {
        return RuleResult({ approved: true, reason: "" });
    }

    /**
     * @notice Evaluates withdraw operations and redirects them to withdrawal manager
     * @param token Address of the tRWA token
     * @param user Address initiating the withdraw
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address token,
        address user,
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (RuleResult memory) {
        // If the withdrawal is coming from the withdrawal manager itself, approve it
        if (msg.sender == address(withdrawalManager)) {
            return RuleResult({ approved: true, reason: "" });
        }

        // Calculate shares equivalent to assets
        uint256 shares = assets > 0 ? tRWA(token).previewWithdraw(assets) : 0;

        // Create withdrawal request in the queue
        withdrawalManager.requestWithdrawal(owner, assets, shares);

        // Reject direct withdrawal with special message - token will recognize this message
        return RuleResult({
            approved: false,
            reason: "Direct withdrawals not supported. Withdrawal request created in queue."
        });
    }

    /**
     * @notice Grant a role to an address
     * @param user Address to grant the role to
     * @param role Role to grant
     */
    function grantRole(address user, uint256 role) external onlyOwner {
        _grantRoles(user, role);
    }

    /**
     * @notice Revoke a role from an address
     * @param user Address to revoke the role from
     * @param role Role to revoke
     */
    function revokeRole(address user, uint256 role) external onlyOwner {
        _revokeRoles(user, role);
    }

    /**
     * @notice Emitted when withdrawal manager is updated
     * @param newWithdrawalManager Address of the new withdrawal manager
     */
    event WithdrawalManagerUpdated(address newWithdrawalManager);
}