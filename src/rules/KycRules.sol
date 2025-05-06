// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseRules} from "./BaseRules.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";

/**
 * @title KycRule
 * @notice Rule that restricts transfers based on sender/receiver addresses
 * @dev Uses allow/deny lists to determine if transfers are permitted
 */
contract KycRules is BaseRules, RoleManaged {
    // Errors
    error ZeroAddress();
    error AddressAlreadyDenied();
    error InvalidArrayLength();

    // Allow and deny lists
    mapping(address => bool) public isAddressAllowed;
    mapping(address => bool) public isAddressDenied;

    // Events
    event AddressAllowed(address indexed account, address indexed operator);
    event AddressDenied(address indexed account, address indexed operator);
    event AddressRestrictionRemoved(address indexed account, address indexed operator);
    event BatchAddressAllowed(uint256 count, address indexed operator);
    event BatchAddressDenied(uint256 count, address indexed operator);
    event BatchAddressRestrictionRemoved(uint256 count, address indexed operator);

    /**
     * @notice Constructor
     * @param _roleManager Address of the role manager contract
     */
    constructor(address _roleManager)
        BaseRules("KycRule")
        RoleManaged(_roleManager)
    {}

    /**
     * @notice Allow an address to transfer/receive tokens
     * @param account Address to allow
     */
    function allow(address account) external onlyRoles(roleManager.KYC_OPERATOR()) {
        if (account == address(0)) revert ZeroAddress();
        if (isAddressDenied[account]) revert AddressAlreadyDenied();

        isAddressAllowed[account] = true;

        emit AddressAllowed(account, msg.sender);
    }

    /**
     * @notice Deny an address from transferring/receiving tokens
     * @param account Address to deny
     */
    function deny(address account) external onlyRoles(roleManager.KYC_OPERATOR()) {
        if (account == address(0)) revert ZeroAddress();

        isAddressAllowed[account] = false;
        isAddressDenied[account] = true;

        emit AddressDenied(account, msg.sender);
    }

    /**
     * @notice Reset an address by removing it from both allow and deny lists
     * @param account Address to reset
     */
    function reset(address account) external onlyRoles(roleManager.KYC_OPERATOR()) {
        if (account == address(0)) revert ZeroAddress();

        isAddressAllowed[account] = false;
        isAddressDenied[account] = false;

        emit AddressRestrictionRemoved(account, msg.sender);
    }

    /**
     * @notice Batch allow addresses to transfer/receive tokens
     * @param accounts Array of addresses to allow
     */
    function batchAllow(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR()) {
        uint256 length = accounts.length;
        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();
            if (isAddressDenied[account]) revert AddressAlreadyDenied();

            isAddressAllowed[account] = true;

            emit AddressAllowed(account, msg.sender);
        }

        emit BatchAddressAllowed(length, msg.sender);
    }

    /**
     * @notice Batch deny addresses from transferring/receiving tokens
     * @param accounts Array of addresses to deny
     */
    function batchDeny(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR()) {
        uint256 length = accounts.length;
        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();

            isAddressAllowed[account] = false;
            isAddressDenied[account] = true;

            emit AddressDenied(account, msg.sender);
        }

        emit BatchAddressDenied(length, msg.sender);
    }

    /**
     * @notice Batch reset addresses by removing them from both allow and deny lists
     * @param accounts Array of addresses to reset
     */
    function batchReset(address[] calldata accounts) external onlyRoles(roleManager.KYC_OPERATOR()) {
        uint256 length = accounts.length;
        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();

            isAddressAllowed[account] = false;
            isAddressDenied[account] = false;

            emit AddressRestrictionRemoved(account, msg.sender);
        }

        emit BatchAddressRestrictionRemoved(length, msg.sender);
    }

    /**
     * @notice Check if an address is allowed to transfer/receive tokens
     * @param account Address to check
     * @return Whether the address is allowed
     */
    function isAllowed(address account) public view returns (bool) {
        // If explicitly denied, always return false (blacklist supersedes whitelist)
        if (isAddressDenied[account] || !isAddressAllowed[account]) {
            return false;
        }

        // If explicitly allowed, return true
        return true;
    }

    /**
     * @notice Evaluate transfer operation
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @return result Rule evaluation result
     */
    function evaluateTransfer(
        address,
        address from,
        address to,
        uint256
    ) public view override returns (RuleResult memory result) {
        // Check if the sender is allowed to transfer
        if (!isAllowed(from)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: sender"
            });
        }

        // Check if the receiver is allowed to receive
        if (!isAllowed(to)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: receiver"
            });
        }

        // Both sender and receiver are allowed
        return RuleResult({ approved: true, reason: "" });
    }

    /**
     * @notice Evaluate deposit operation
     * @param user Address initiating the deposit
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address,
        address user,
        uint256,
        address receiver
    ) public view override returns (RuleResult memory result) {
        // Check if sender is allowed to deposit
        if (!isAllowed(user)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: sender"
            });
        }

        // Check if the receiver is allowed to receive
        if (!isAllowed(receiver)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: receiver"
            });
        }

        // Both minter and receiver are allowed
        return RuleResult({ approved: true, reason: "" });
    }

    /**
     * @notice Evaluate withdraw operation
     * @param user Address initiating the withdrawal
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address,
        address user,
        uint256,
        address receiver,
        address owner
    ) public view override returns (RuleResult memory result) {
        // Check if sender is allowed to withdraw
        if (!isAllowed(user)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: sender"
            });
        }

        // Check if the owner is allowed
        if (!isAllowed(owner)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: owner"
            });
        }

        // Check if the receiver is allowed
        if (!isAllowed(receiver)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: receiver"
            });
        }

        // All parties are allowed
        return RuleResult({ approved: true, reason: "" });
    }
}
