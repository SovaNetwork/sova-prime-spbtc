// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ItRWAHook} from "../interfaces/ItRWAHook.sol";
import {IRuleEngine} from "../interfaces/IRuleEngine.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/**
 * @title RuleEngineHook
 * @notice Hook implementation that connects the tRWA's hook system with the RuleEngine
 * @dev This creates backward compatibility with older systems while allowing the modern rule system
 */
contract RuleEngineHook is ItRWAHook, OwnableRoles {
    // Role for managing the hook
    uint256 public constant HOOK_ADMIN_ROLE = 1 << 0;

    // The rule engine to consult
    address public ruleEngine;

    // The tRWA token this hook is for
    address public tRWAToken;

    // Events
    event RuleEngineUpdated(address indexed oldEngine, address indexed newEngine);

    /**
     * @notice Constructor
     * @param admin Address of the admin
     * @param _ruleEngine Address of the rule engine
     * @param _tRWAToken Address of the tRWA token
     */
    constructor(address admin, address _ruleEngine, address _tRWAToken) {
        if (admin == address(0)) revert("Invalid admin address");
        if (_ruleEngine == address(0)) revert("Invalid rule engine address");
        if (_tRWAToken == address(0)) revert("Invalid tRWA token address");

        _initializeOwner(admin);
        _grantRoles(admin, HOOK_ADMIN_ROLE);

        ruleEngine = _ruleEngine;
        tRWAToken = _tRWAToken;
    }

    /**
     * @notice Set or update the rule engine
     * @param _ruleEngine Address of the rule engine
     */
    function setRuleEngine(address _ruleEngine) external onlyOwnerOrRoles(HOOK_ADMIN_ROLE) {
        if (_ruleEngine == address(0)) revert("Invalid rule engine address");

        address oldEngine = ruleEngine;
        ruleEngine = _ruleEngine;

        emit RuleEngineUpdated(oldEngine, _ruleEngine);
    }

    /**
     * @notice Hook called before deposit
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return Whether the operation is allowed
     */
    function beforeDeposit(address user, uint256 assets, address receiver) external override returns (bool) {
        // Call the rule engine to check if deposit is allowed
        try IRuleEngine(ruleEngine).checkDeposit(user, assets, receiver) returns (bool allowed) {
            return allowed;
        } catch {
            // If rule engine reverts, deny the operation
            return false;
        }
    }

    /**
     * @notice Hook called before mint
     * @param user Address initiating the mint
     * @param shares Amount of shares being minted
     * @param receiver Address receiving the shares
     * @return Whether the operation is allowed
     */
    function beforeMint(address user, uint256 shares, address receiver) external override returns (bool) {
        // Call the rule engine to check if mint is allowed
        try IRuleEngine(ruleEngine).checkMint(user, shares, receiver) returns (bool allowed) {
            return allowed;
        } catch {
            // If rule engine reverts, deny the operation
            return false;
        }
    }

    /**
     * @notice Hook called before withdraw
     * @param user Address initiating the withdrawal
     * @param assets Amount of assets being withdrawn
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return Whether the operation is allowed
     */
    function beforeWithdraw(address user, uint256 assets, address receiver, address owner) external override returns (bool) {
        // Call the rule engine to check if withdraw is allowed
        try IRuleEngine(ruleEngine).checkWithdraw(user, assets, receiver, owner) returns (bool allowed) {
            return allowed;
        } catch {
            // If rule engine reverts, deny the operation
            return false;
        }
    }

    /**
     * @notice Hook called before redeem
     * @param user Address initiating the redemption
     * @param shares Amount of shares being redeemed
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return Whether the operation is allowed
     */
    function beforeRedeem(address user, uint256 shares, address receiver, address owner) external override returns (bool) {
        // Call the rule engine to check if redeem is allowed
        try IRuleEngine(ruleEngine).checkRedeem(user, shares, receiver, owner) returns (bool allowed) {
            return allowed;
        } catch {
            // If rule engine reverts, deny the operation
            return false;
        }
    }

    /**
     * @notice Hook called before transfer
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param value Amount of tokens being transferred
     * @return Whether the operation is allowed
     */
    function beforeTransfer(address from, address to, uint256 value) external override returns (bool) {
        // Call the rule engine to check if transfer is allowed
        try IRuleEngine(ruleEngine).checkTransfer(from, to, value) returns (bool allowed) {
            return allowed;
        } catch {
            // If rule engine reverts, deny the operation
            return false;
        }
    }

    /**
     * @notice Hook called after deposit
     * @param user Address that initiated the deposit
     * @param assets Amount of assets deposited
     * @param receiver Address that received the shares
     * @param shares Amount of shares minted
     */
    function afterDeposit(address user, uint256 assets, address receiver, uint256 shares) external override {
        // Post-operation hooks don't need to revert
    }

    /**
     * @notice Hook called after mint
     * @param user Address that initiated the mint
     * @param shares Amount of shares minted
     * @param receiver Address that received the shares
     * @param assets Amount of assets deposited
     */
    function afterMint(address user, uint256 shares, address receiver, uint256 assets) external override {
        // Post-operation hooks don't need to revert
    }

    /**
     * @notice Hook called after withdraw
     * @param user Address that initiated the withdrawal
     * @param assets Amount of assets withdrawn
     * @param receiver Address that received the assets
     * @param owner Address that owned the shares
     * @param shares Amount of shares burned
     */
    function afterWithdraw(address user, uint256 assets, address receiver, address owner, uint256 shares) external override {
        // Post-operation hooks don't need to revert
    }

    /**
     * @notice Hook called after redeem
     * @param user Address that initiated the redemption
     * @param shares Amount of shares redeemed
     * @param receiver Address that received the assets
     * @param owner Address that owned the shares
     * @param assets Amount of assets received
     */
    function afterRedeem(address user, uint256 shares, address receiver, address owner, uint256 assets) external override {
        // Post-operation hooks don't need to revert
    }

    /**
     * @notice Hook called after transfer
     * @param from Address that sent tokens
     * @param to Address that received tokens
     * @param value Amount of tokens transferred
     */
    function afterTransfer(address from, address to, uint256 value) external override {
        // Post-operation hooks don't need to revert
    }
}