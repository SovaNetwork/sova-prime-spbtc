// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "./IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";

/**
 * @title BasicStrategy
 * @notice A basic strategy contract for managing tRWA assets
 * @dev Each strategy deploys its own tRWA token (sToken)
 *
 * Consider for future: Making BasicStrategy an ERC4337-compatible smart account
 */
abstract contract BasicStrategy is IStrategy, RoleManaged {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // The registry field is inherited from RoleManaged
    address public manager;
    address public asset;
    address public sToken;
    address public controller;

    // Initialization flags to prevent re-initialization
    bool private _initialized;
    bool private _controllerConfigured;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy implementation
     * @dev Empty constructor for implementation contract
     */
    constructor(address _roleManager) RoleManaged(_roleManager) {}

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
        bytes memory // initData
    ) public virtual override {
        // Prevent re-initialization
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

        // Set up strategy configuration
        // Unlike other protocol roles, only a single manager is allowed
        manager = manager_;
        asset = asset_;

        tRWA newToken = new tRWA(
            name_,
            symbol_,
            asset,
            assetDecimals_,
            address(this)
        );

        sToken = address(newToken);

        emit StrategyInitialized(address(0), manager, asset, sToken);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow admin to change the manager
     * @param newManager The new manager
     */
    function setManager(address newManager) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        // Can set to 0 to disable manager
        manager = newManager;

        emit ManagerChange(manager, newManager);
    }

    /*//////////////////////////////////////////////////////////////
                            ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view virtual returns (uint256);

    /**
     * @notice Transfer assets from the strategy to a user
     * @param user Address to transfer assets to
     * @param amount Amount of assets to transfer
     */
    function transferAssets(address user, uint256 amount) external virtual;

    /**
     * @notice Send owned ETH to an address
     * @param to The address to send the ETH to
     */
    function sendETH(address to) external onlyManager {
        payable(to).transfer(address(this).balance);
    }

    /**
     * @notice Send owned ERC20 tokens to an address
     * @param tokenAddr The address of the ERC20 token to send
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to send
     */
    function sendToken(address tokenAddr, address to, uint256 amount) external onlyManager {
        tokenAddr.safeTransfer(to, amount);
    }

    /**
     * @notice Pull ERC20 tokens from an external contract into this contract
     * @param tokenAddr The address of the ERC20 token to pull
     * @param from The address to pull the tokens from
     * @param amount The amount of tokens to pull
     */
    function pullToken(address tokenAddr, address from, uint256 amount) external onlyManager {
        tokenAddr.safeTransferFrom(from, address(this), amount);
    }

    /**
     * @notice Set the allowance for an ERC20 token
     * @param tokenAddr The address of the ERC20 token to set the allowance for
     * @param spender The address to set the allowance for
     * @param amount The amount of allowance to set
     */
    function setAllowance(address tokenAddr, address spender, uint256 amount) external onlyManager {
        ERC20(tokenAddr).approve(spender, amount);
    }

    /**
     * @notice Call the strategy token
     * @dev Used for configuring token hooks
     * @param data The calldata to call the strategy token with
     */
    function callStrategyToken(bytes calldata data) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        (bool success, bytes memory returnData) = sToken.call(data);

        if (!success) {
            revert CallRevert(returnData);
        }

        emit Call(sToken, 0, data);
    }

    /**
     * @notice Execute arbitrary transactions on behalf of the strategy
     * @param target Address of the contract to call
     * @param value Amount of ETH to send
     * @param data Calldata to send
     * @return success Whether the call succeeded
     * @return returnData The return data from the call
     */
    function call(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyManager returns (bool success, bytes memory returnData) {
        if (target == address(0) || target == address(this)) revert InvalidAddress();
        if (target == sToken) revert CannotCallToken();

        (success, returnData) = target.call{value: value}(data);
        if (!success) {
            revert CallRevert(returnData);
        }

        emit Call(target, value, data);
    }

    /**
     * @notice Delegate call an arbitrary function
     * @param target Address of the contract to call
     * @param data Calldata to send
     * @return success Whether the call succeeded
     * @return returnData The return data from the call
     */
    function delegateCall(
        address target,
        bytes calldata data
    ) external onlyManager returns (bool success, bytes memory returnData) {
        (success, returnData) = target.delegatecall(data);
    }

    /**
     * @notice Configure the subscription controller for this strategy
     * @param _controller Controller address
     */
    function configureController(address _controller) external {
        // Only callable by the manager - in production this would be the registry
        if (msg.sender != manager) revert Unauthorized();
        // Can only be configured once
        if (_controllerConfigured) revert AlreadyInitialized();
        // Validate controller address
        if (_controller == address(0)) revert InvalidAddress();

        controller = _controller;
        _controllerConfigured = true;

        // Setting controller is now handled internally - removed setController call

        emit ControllerConfigured(_controller);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyManager() {
        if (msg.sender != manager) revert Unauthorized();
        _;
    }
}