// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title MockStrategy
 * @notice A simple strategy implementation for testing
 */
contract MockStrategy is IStrategy {
    address public manager;
    address public asset;
    address public sToken;
    address public deployer;
    address public controller;
    uint256 private _balance;
    bool private _initialized;
    bool private _controllerConfigured;

    /**
     * @notice Initialize the strategy
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Number of decimals of the asset
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory
    ) external override {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();
        if (roleManager_ == address(0)) revert InvalidAddress();
        // Deploy token with no hooks initially
        sToken = address(new tRWA(name_, symbol_, asset_, assetDecimals_, address(this)));

        deployer = msg.sender;
        manager = manager_;
        asset = asset_;
        _balance = 0;

        emit StrategyInitialized(address(0), manager_, asset_, sToken);
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
        // Return actual ERC20 balance instead of _balance for more realistic testing
        return IERC20(asset).balanceOf(address(this));
    }

    /**
     * @notice Transfer assets to a user
     * @param amount Amount of assets to transfer
     */
    function transferAssets(address, uint256 amount) external {
        // Only callable by token or manager
        if (msg.sender != sToken && msg.sender != manager) revert Unauthorized();

        // Simulate asset transfer
        _balance -= amount;

        // Mock the actual transfer since this is a test contract
        // In a real implementation, this would use SafeTransferLib to transfer the asset
    }

    function setManager(address newManager) external {
        // In a real implementation, this would be restricted to the appropriate role
        if (msg.sender != manager) revert Unauthorized();

        address oldManager = manager;
        manager = newManager;
        emit ManagerChange(oldManager, newManager);
    }

    /**
     * @notice Call tRWA token with arbitrary data (for testing)
     * @param data The data to call the token with
     */
    function callStrategyToken(bytes calldata data) external returns (bool success, bytes memory returnData) {
        // Only callable by manager
        if (msg.sender != manager && msg.sender != deployer) revert Unauthorized();

        return sToken.call(data);
    }

}