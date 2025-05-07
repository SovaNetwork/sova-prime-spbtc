// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from "../strategy/IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title MockStrategy
 * @notice A simple strategy implementation for testing
 */
contract MockStrategy is IStrategy {
    constructor(address _roleManager) {}
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
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory
    ) external override {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

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
        return _balance;
    }

    /**
     * @notice Transfer assets to a user
     * @param user Address to transfer assets to
     * @param amount Amount of assets to transfer
     */
    function transferAssets(address user, uint256 amount) external {
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
     * @notice Configure the controller for this strategy
     * @param _controller Controller address
     */
    function configureController(address _controller) external {
        // In a real implementation, this would have proper access control

        // Can only be configured once
        if (_controllerConfigured) revert AlreadyInitialized();

        // Validate controller address
        if (_controller == address(0)) revert InvalidAddress();

        controller = _controller;
        _controllerConfigured = true;

        // Set controller reference in token (mock implementation)
        // tRWA(sToken).setController(_controller);

        emit ControllerConfigured(_controller);
    }
}