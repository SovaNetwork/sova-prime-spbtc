// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title BasicStrategy
 * @notice A basic strategy contract for managing tRWA assets
 *
 * Consider for future: Making BasicStrategy an ERC4337-compatible smart account
 */
abstract contract BasicStrategy is IStrategy {
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    address public admin;
    address public pendingAdmin;
    address public manager;
    ERC20 public asset;

    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/

    // Errors
    error InvalidAddress();
    error Unauthorized();
    error CallRevert(bytes returnData);

    // Events
    event PendingAdminChange(address indexed oldAdmin, address indexed newAdmin);
    event AdminChange(address indexed oldAdmin, address indexed newAdmin);
    event NoAdminChange(address indexed oldAdmin, address indexed cancelledAdmin);
    event ManagerChange(address indexed oldManager, address indexed newManager);
    event Call(address indexed target, uint256 value, bytes data);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param admin_ Address of the admin
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     */
    constructor(address admin_, address manager_, address asset_) {
        if (admin_ == address(0)) revert InvalidAddress();
        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

        // Let admin and manager be contract variables
        // and grant them the roles
        admin = admin_;
        manager = manager_;
        asset = ERC20(asset_);
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
     * @param token The address of the ERC20 token to send
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to send
     */
    function sendToken(address token, address to, uint256 amount) external onlyManager {
        ERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Pull ERC20 tokens from an external contract into this contract
     * @param token The address of the ERC20 token to pull
     * @param from The address to pull the tokens from
     * @param amount The amount of tokens to pull
     */
    function pullToken(address token, address from, uint256 amount) external onlyManager {
        ERC20(token).safeTransferFrom(from, address(this), amount);
    }

    /**
     * @notice Set the allowance for an ERC20 token
     * @param token The address of the ERC20 token to set the allowance for
     * @param spender The address to set the allowance for
     * @param amount The amount of allowance to set
     */
    function setAllowance(address token, address spender, uint256 amount) external onlyManager {
        ERC20(token).approve(spender, amount);
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