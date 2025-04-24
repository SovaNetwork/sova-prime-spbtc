// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IRules} from "../rules/IRules.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {ItRWA} from "./ItRWA.sol";

/**
 * @title ICallbackReceiver
 * @notice Interface for contracts that want to receive token operation callbacks
 */
interface ICallbackReceiver {
    /**
     * @notice Callback function for token operations
     * @param operationType Type of operation (keccak256 of operation name)
     * @param success Whether the operation was successful
     * @param data Additional data passed from the caller
     */
    function operationCallback(
        bytes32 operationType,
        bool success,
        bytes memory data
    ) external;
}

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) inheriting ERC4626 standard
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC4626, ItRWA {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    // Internal storage for token metadata
    uint8 private constant DECIMALS = 18;
    string private _symbol;
    string private _name;
    address private immutable _asset;

    // Logic contracts
    IStrategy public immutable strategy;
    IRules public immutable rules;
    address public controller;

    // Events for withdrawal queueing
    event WithdrawalQueued(address indexed user, uint256 assets, uint256 shares);

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param strategy_ Strategy address
     * @param rules_ Rules address
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        address strategy_,
        address rules_
    ) {
        // Validate configuration parameters
        if (asset_ == address(0)) revert InvalidAddress();
        if (strategy_ == address(0)) revert InvalidAddress();
        if (rules_ == address(0)) revert InvalidAddress();

        _name = name_;
        _symbol = symbol_;
        _asset = asset_;

        strategy = IStrategy(strategy_);
        rules = IRules(rules_);
    }

    /**
     * @notice Set the controller address
     * @param _controller Controller address
     */
    function setController(address _controller) external {
        // Only callable once during initialization by strategy
        if (msg.sender != address(strategy)) revert tRWAUnauthorized(msg.sender, address(strategy));
        if (controller != address(0)) revert ControllerAlreadySet();
        if (_controller == address(0)) revert InvalidAddress();

        controller = _controller;
    }

    /**
     * @notice Returns the name of the token
     * @return Name of the token
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     * @return Symbol of the token
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the asset of the token
     * @return Asset of the token
     */
    function asset() public view virtual override returns (address) {
        return _asset;
    }

    /**
     * @notice Returns the decimals places of the token
     */
    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Returns the total assets of the strategy
     * @return Total assets in terms of _asset
     */
    function totalAssets() public view override returns (uint256) {
        return strategy.balance();
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Extended deposit function with callback support
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @param useCallback Whether to use callback
     * @param callbackData Data to pass to the callback
     * @return shares Amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 shares) {
        // Execute the standard deposit
        shares = deposit(assets, receiver);

        // Execute callback if requested
        if (useCallback && msg.sender.code.length > 0) {
            _executeCallback(keccak256("DEPOSIT"), true, callbackData);
        }

        return shares;
    }

    /**
     * @notice Extended mint function with callback support
     * @param shares Amount of shares to mint
     * @param receiver Address receiving the shares
     * @param useCallback Whether to use callback
     * @param callbackData Data to pass to the callback
     * @return assets Amount of assets deposited
     */
    function mint(
        uint256 shares,
        address receiver,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 assets) {
        // Execute the standard mint
        assets = mint(shares, receiver);

        // Execute callback if requested
        if (useCallback && msg.sender.code.length > 0) {
            _executeCallback(keccak256("MINT"), true, callbackData);
        }

        return assets;
    }

    /**
     * @notice Extended withdraw function with callback support
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @param useCallback Whether to use callback
     * @param callbackData Data to pass to the callback
     * @return shares Amount of shares burned
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 shares) {
        bool success = false;

        try this.withdraw(assets, receiver, owner) returns (uint256 _shares) {
            shares = _shares;
            success = true;
        } catch Error(string memory reason) {
            // Check if withdrawal was queued
            if (keccak256(bytes(reason)) == keccak256(bytes("RuleCheckFailed(Direct withdrawals not supported. Withdrawal request created in queue.)"))) {
                // This is a successful queuing, not a failure
                shares = 0;
                success = true;

                // Need to calculate shares for the callback
                shares = previewWithdraw(assets);
            } else {
                // Other error occurred
                success = false;
                shares = 0;
            }
        }

        // Execute callback if requested
        if (useCallback && msg.sender.code.length > 0) {
            _executeCallback(keccak256("WITHDRAW"), success, callbackData);
        }

        return shares;
    }

    /**
     * @notice Extended redeem function with callback support
     * @param shares Amount of shares to redeem
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @param useCallback Whether to use callback
     * @param callbackData Data to pass to the callback
     * @return assets Amount of assets redeemed
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        bool useCallback,
        bytes calldata callbackData
    ) external returns (uint256 assets) {
        bool success = false;

        try this.redeem(shares, receiver, owner) returns (uint256 _assets) {
            assets = _assets;
            success = true;
        } catch Error(string memory reason) {
            // Check if withdrawal was queued
            if (keccak256(bytes(reason)) == keccak256(bytes("RuleCheckFailed(Direct withdrawals not supported. Withdrawal request created in queue.)"))) {
                // This is a successful queuing, not a failure
                assets = 0;
                success = true;

                // Need to calculate assets for the callback
                assets = previewRedeem(shares);
            } else {
                // Other error occurred
                success = false;
                assets = 0;
            }
        }

        // Execute callback if requested
        if (useCallback && msg.sender.code.length > 0) {
            _executeCallback(keccak256("REDEEM"), success, callbackData);
        }

        return assets;
    }

    /**
     * @notice Helper function to execute callbacks
     * @param operationType Type of operation
     * @param success Whether operation was successful
     * @param callbackData Data to pass to callback
     */
    function _executeCallback(
        bytes32 operationType,
        bool success,
        bytes memory callbackData
    ) internal {
        try ICallbackReceiver(msg.sender).operationCallback(
            operationType,
            success,
            callbackData
        ) {} catch {
            // Silently handle callback errors to avoid affecting main operations
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit assets into the token
     * @param by Address of the sender
     * @param to Address of the receiver
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares to mint
     */
    function _deposit(address by, address to, uint256 assets, uint256 shares) internal override {
        IRules.RuleResult memory result = rules.evaluateDeposit(address(this), by, assets, to);

        if (!result.approved) revert RuleCheckFailed(result.reason);

        SafeTransferLib.safeTransferFrom(asset(), by, address(this), assets);
        _mint(to, shares);

        // Notify subscription controller if set
        if (controller != address(0)) {
            // Pack data for callback
            bytes memory callbackData = abi.encode(to, assets);

            // Use callback pattern
            if (controller.code.length > 0) {
                try ICallbackReceiver(controller).operationCallback(
                    keccak256("DEPOSIT"),
                    true,
                    callbackData
                ) {} catch {}
            }
        }

        emit Deposit(by, to, assets, shares);
    }

    /**
     * @notice Withdraw assets from the token
     * @param by Address of the sender
     * @param to Address of the receiver
     * @param owner Address of the owner
     * @param assets Amount of assets to withdraw
     * @param shares Amount of shares to withdraw
     */
    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares) internal override {
       IRules.RuleResult memory result = rules.evaluateWithdraw(address(this), by, assets, to, owner);

       if (!result.approved) {
           // Special case for withdrawal queue
           if (keccak256(bytes(result.reason)) == keccak256(bytes("Direct withdrawals not supported. Withdrawal request created in queue."))) {
               // Emit event for withdrawal queueing
               emit WithdrawalQueued(owner, assets, shares);
           }

           // Always revert with the rule's reason
           revert RuleCheckFailed(result.reason);
       }

       if (by != owner) {
           _spendAllowance(owner, by, shares);
       }

       if (shares > balanceOf(owner))
           revert WithdrawMoreThanMax();

       _burn(owner, shares);

       // Safe transfer the assets to the recipient
       SafeTransferLib.safeTransfer(asset(), to, assets);

       emit Withdraw(by, to, owner, assets, shares);
    }

    /**
     * @notice Utility function to burn tokens
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external {
        // Only the strategy or authorized contracts can call this
        IRules.RuleResult memory result = rules.evaluateTransfer(address(this), from, address(0), amount);

        if (!result.approved) {
            revert RuleCheckFailed(result.reason);
        }

        _burn(from, amount);
    }
}