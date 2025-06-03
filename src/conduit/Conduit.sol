// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {ItRWA} from "../token/ItRWA.sol";
import {IRegistry} from "../registry/IRegistry.sol";
contract Conduit is RoleManaged {
    using SafeTransferLib for address;

    // Custom errors
    error InvalidAmount();
    error InvalidToken();
    error InvalidDestination();
    error UnsupportedAsset();

    /**
     * @notice Constructor
     * @dev Constructor is called by the registry contract
     * @param _roleManager Address of the role manager contract
     */
    constructor(address _roleManager) RoleManaged(_roleManager) {}

    /**
     * @dev Executes a token transfer on behalf of an approved tRWA contract.
     * The user (`_from`) must have approved this Conduit contract to spend `_amount` of `_token`.
     * Only callable by an `approvedTRWAContracts`.
     * @param token The address of the ERC20 token to transfer.
     * @param from The address of the user whose tokens are being transferred.
     * @param to The address to transfer the tokens to (e.g., the tRWA contract or a designated vault).
     * @param amount The amount of tokens to transfer.
     */
    function collectDeposit(
        address token,
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        if (amount == 0) revert InvalidAmount();
        if (IRegistry(registry()).allowedAssets(token) == 0) revert InvalidToken();
        if (!IRegistry(registry()).isStrategyToken(msg.sender)) revert InvalidDestination();
        if (ItRWA(msg.sender).asset() != token) revert UnsupportedAsset();

        // The core logic: transfer tokens from 'from' to 'to'.
        // This relies on the user ('from') having previously called approve() on the 'token'
        // contract, granting this Conduit contract an allowance.

        // Perform the transfer using SafeTransferLib
        token.safeTransferFrom(from, to, amount);

        return true;
    }

    /**
     * @notice Rescues ERC20 tokens from the conduit
     * @param tokenAddress The address of the ERC20 token to rescue
     * @param to The address to transfer the tokens to
     * @param amount The amount of tokens to transfer
     */
    function rescueERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyRoles(roleManager.PROTOCOL_ADMIN()) {
        tokenAddress.safeTransfer(to, amount);
    }
}
