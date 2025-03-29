// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "./BaseRules.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title KycRule
 * @notice Rule that restricts transfers based on sender/receiver addresses
 * @dev Uses allow/deny lists to determine if transfers are permitted
 */
contract KycRules is BaseRules, Ownable {
    // Allow and deny lists
    mapping(address => bool) public isAddressAllowed;
    mapping(address => bool) public isAddressDenied;

    // Default allow/deny state
    bool public defaultAllow;

    // Events
    event AddressAllowed(address indexed account);
    event AddressDenied(address indexed account);
    event AddressRestrictionRemoved(address indexed account);
    event DefaultAllowChanged(bool defaultAllow);

    /**
     * @notice Constructor
     * @param admin Address of the admin
     * @param _defaultAllow Whether transfers are allowed by default
     */
    constructor(address admin, bool _defaultAllow)
        BaseRules("KycRule")
    {
        if (admin == address(0)) revert("Invalid admin address");

        _initializeOwner(admin);

        defaultAllow = _defaultAllow;
    }

    /**
     * @notice Allow an address to transfer/receive tokens
     * @param account Address to allow
     */
    function allowAddress(address account) external onlyOwner {
        if (account == address(0)) revert("Invalid address");
        if (isAddressDenied[account]) revert("Address is denied");

        isAddressAllowed[account] = true;

        emit AddressAllowed(account);
    }

    /**
     * @notice Deny an address from transferring/receiving tokens
     * @param account Address to deny
     */
    function denyAddress(address account) external onlyOwner {
        if (account == address(0)) revert("Invalid address");

        isAddressAllowed[account] = false;
        isAddressDenied[account] = true;

        emit AddressDenied(account);
    }

    /**
     * @notice Remove an address from both allow and deny lists
     * @param account Address to remove
     */
    function removeAddressRestriction(address account) external onlyOwner {
        if (account == address(0)) revert("Invalid address");

        isAddressAllowed[account] = false;
        isAddressDenied[account] = false;

        emit AddressRestrictionRemoved(account);
    }

    /**
     * @notice Set the default allow state
     * @param _defaultAllow Whether transfers are allowed by default
     */
    function setDefaultAllow(bool _defaultAllow) external onlyOwner {
        defaultAllow = _defaultAllow;

        emit DefaultAllowChanged(_defaultAllow);
    }

    /**
     * @notice Check if an address is allowed to transfer/receive tokens
     * @param account Address to check
     * @return Whether the address is allowed
     */
    function isAllowed(address account) public view returns (bool) {
        // If explicitly allowed, return true
        if (isAddressAllowed[account]) {
            return true;
        }

        // If explicitly denied, return false
        if (isAddressDenied[account]) {
            return false;
        }

        // Otherwise, return the default state
        return defaultAllow;
    }

    /**
     * @notice Evaluate transfer operation
     * @param tRWAToken Address of the tRWA token
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param amount Amount of tokens being transferred
     * @return result Rule evaluation result
     */
    function evaluateTransfer(
        address tRWAToken,
        address from,
        address to,
        uint256 amount
    ) external view override returns (RuleResult memory result) {
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
     * @param tRWAToken Address of the tRWA token
     * @param user Address initiating the deposit
         * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address tRWAToken,
        address user,
        uint256 assets,
        address receiver
    ) external view override returns (RuleResult memory result) {
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
     * @notice Evaluate mint operation
     * @param tRWAToken Address of the tRWA token
     * @param user Address initiating the mint
     * @param shares Amount of shares being minted
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateMint(
        address tRWAToken,
        address user,
        uint256 shares,
        address receiver
    ) external view override returns (RuleResult memory result) {
        // Check if sender is allowed to mint
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
     * @param tRWAToken Address of the tRWA token
     * @param user Address initiating the withdrawal
     * @param assets Amount of assets being withdrawn
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address tRWAToken,
        address user,
        uint256 assets,
        address receiver,
        address owner
    ) external view override returns (RuleResult memory result) {
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

    /**
     * @notice Evaluate redeem operation
     * @param tRWAToken Address of the tRWA token
     * @param user Address initiating the redemption
     * @param shares Amount of shares being redeemed
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateRedeem(
        address tRWAToken,
        address user,
        uint256 shares,
        address receiver,
        address owner
    ) external view override returns (RuleResult memory result) {
        // Check if sender is allowed to redeem
        if (!isAllowed(user)) {
            return RuleResult({
                approved: false,
                reason: "KycRules: sender"
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
