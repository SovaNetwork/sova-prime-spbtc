// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "./IStrategy.sol";
import {tRWA} from "../token/tRWA.sol";

/**
 * @title BasicStrategy
 * @notice A basic strategy contract for managing tRWA assets
 * @dev Each strategy deploys its own tRWA token (sToken)
 *
 * Consider for future: Making BasicStrategy an ERC4337-compatible smart account
 */
abstract contract BasicStrategy is IStrategy {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    address public admin;
    address public pendingAdmin;
    address public manager;
    address public asset;
    address public sToken;

    // Initialization flag to prevent re-initialization
    bool private _initialized;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy implementation
     * @dev Empty constructor for implementation contract
     */
    constructor() {}

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
        bytes memory // initData
    ) public virtual {
        // Prevent re-initialization
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        if (admin_ == address(0)) revert InvalidAddress();
        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();
        if (rules_ == address(0)) revert InvalidRules();

        // Set up strategy configuration
        admin = admin_;
        manager = manager_;
        asset = asset_;

        // Deploy associated tRWA token
        tRWA newToken = new tRWA(
            name_,
            symbol_,
            asset_,
            address(this),
            rules_
        );

        sToken = address(newToken);

        emit StrategyInitialized(admin_, manager_, asset_, sToken);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow admin to change the manager
     * @param newManager The new manager
     */
    function setManager(address newManager) external onlyAdmin {
        // Can set to 0 to disable manager
        manager = newManager;

        emit ManagerChange(manager, newManager);
    }

    /**
     * @notice First step of admin change - propose new admin
     * @param newAdmin The proposed new admin
     */
    function proposeAdmin(address newAdmin) external onlyAdmin {
        pendingAdmin = newAdmin;

        emit PendingAdminChange(admin, newAdmin);
    }

    /**
     * @notice Second step of admin change - accept admin role
     */
    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) revert Unauthorized();

        address oldAdmin = admin;
        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit AdminChange(oldAdmin, admin);
    }

    /**
     * @notice Cancel the pending admin change
     */
    function cancelAdminChange() external {
        if (msg.sender != admin && msg.sender != pendingAdmin) revert Unauthorized();

        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = address(0);

        emit NoAdminChange(admin, oldPendingAdmin);
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
        if (target == address(0)) revert InvalidAddress();

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

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyManager() {
        if (msg.sender != manager) revert Unauthorized();
        _;
    }
}