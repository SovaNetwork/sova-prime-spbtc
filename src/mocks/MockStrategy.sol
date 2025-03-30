// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title MockStrategy
 * @notice A simple strategy implementation for testing
 */
contract MockStrategy is IStrategy {
    address public admin;
    address public pendingAdmin;
    address public manager;
    address public asset;
    address public sToken;
    uint256 private _balance;
    bool private _initialized;

    /**
     * @notice Initialize the strategy
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param admin_ Address of the admin
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param rules_ Rules address
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address admin_,
        address manager_,
        address asset_,
        address rules_,
        bytes memory
    ) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (admin_ == address(0)) revert InvalidAddress();
        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();
        if (rules_ == address(0)) revert InvalidRules();

        admin = admin_;
        manager = manager_;
        asset = asset_;

        tRWA newToken = new tRWA(
            name_,
            symbol_,
            asset_,
            address(this),
            rules_
        );

        sToken = address(newToken);
        _balance = 0;

        emit StrategyInitialized(admin_, manager_, asset_, sToken);
    }

    /**
     * @notice Set the strategy balance directly (for testing)
     * @param amount The new balance amount
     */
    function setBalance(uint256 amount) external {
        _balance = amount;
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view returns (uint256) {
        return _balance;
    }

    function setManager(address newManager) external onlyAdmin {
        manager = newManager;
        emit ManagerChange(manager, newManager);
    }

    function proposeAdmin(address newAdmin) external onlyAdmin {
        pendingAdmin = newAdmin;
        emit PendingAdminChange(admin, newAdmin);
    }

    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) revert Unauthorized();
        address oldAdmin = admin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminChange(oldAdmin, admin);
    }

    function cancelAdminChange() external {
        if (msg.sender != admin && msg.sender != pendingAdmin) revert Unauthorized();
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = address(0);
        emit NoAdminChange(admin, oldPendingAdmin);
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
}