// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IOperationHook, HookOutput} from "../rules/IOperationHook.sol";
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

    // Custom errors
    error AssetDecimalsTooHigh();
    error InvalidAddress();
    error ControllerAlreadySet();
    error tRWAUnauthorized(address caller, address expected);
    error HookCheckFailed(string reason);
    error WithdrawMoreThanMax();
    error NotStrategyAdmin();
    error HookAddressZero();
    error ReorderInvalidLength();
    error ReorderIndexOutOfBounds();
    error ReorderDuplicateIndex();

    // Internal storage for token metadata
    string private _symbol;
    string private _name;
    address private immutable _asset;
    uint8 private immutable _assetDecimals;

    // Logic contracts
    IStrategy public immutable strategy;
    IOperationHook[] public operationHooks;
    address public controller;

    // Events for withdrawal queueing
    event WithdrawalQueued(address indexed user, uint256 assets, uint256 shares);
    event OperationHookAdded(address indexed hookAddress, uint256 index);
    event OperationHooksReordered(uint256[] newIndices);

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Decimals of the asset token
     * @param strategy_ Strategy address
     * @param hookAddresses Array of operation hook contract addresses
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint8 assetDecimals_,
        address strategy_,
        address[] memory hookAddresses
    ) {
        // Validate configuration parameters
        if (asset_ == address(0)) revert InvalidAddress();
        if (strategy_ == address(0)) revert InvalidAddress();
        if (hookAddresses.length == 0) revert InvalidAddress();
        for (uint i = 0; i < hookAddresses.length; i++) {
            if (hookAddresses[i] == address(0)) revert InvalidAddress();
        }

        _name = name_;
        _symbol = symbol_;
        _asset = asset_;
        _assetDecimals = assetDecimals_;

        strategy = IStrategy(strategy_);
        operationHooks = new IOperationHook[](hookAddresses.length);

        for (uint i = 0; i < hookAddresses.length; i++) {
            operationHooks[i] = IOperationHook(hookAddresses[i]);
        }
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
     * @notice Returns the total amount of the underlying asset managed by the Vault.
     * @dev This value is expected by the base ERC4626 implementation to be in terms of asset's native decimals.
     * @return Total assets in terms of _asset
     */
    function totalAssets() public view override returns (uint256) {
        return strategy.balance(); // Returns balance in `_assetDecimals`
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the decimals of the underlying asset token.
     */
    function _underlyingDecimals() internal view virtual override returns (uint8) {
        return _assetDecimals;
    }

    /**
     * @dev Returns the offset to adjust share decimals relative to asset decimals.
     * Ensures that `_underlyingDecimals() + _decimalsOffset()` equals `decimals()` (18 for tRWA shares).
     */
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return _DEFAULT_UNDERLYING_DECIMALS - _assetDecimals;
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
        for (uint i = 0; i < operationHooks.length; i++) {
            HookOutput memory hookOutput = operationHooks[i].evaluateDeposit(address(this), by, assets, to);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
        }

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
       for (uint i = 0; i < operationHooks.length; i++) {
            HookOutput memory hookOutput = operationHooks[i].evaluateWithdraw(address(this), by, assets, to, owner);
            if (!hookOutput.approved) {
                // Special case for withdrawal queue still needs to be handled based on the hook's reason
                if (keccak256(bytes(hookOutput.reason)) == keccak256(bytes("Direct withdrawals not supported. Withdrawal request created in queue."))) {
                    emit WithdrawalQueued(owner, assets, shares);
                }
                revert HookCheckFailed(hookOutput.reason);
            }
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
        for (uint i = 0; i < operationHooks.length; i++) {
            HookOutput memory hookOutput = operationHooks[i].evaluateTransfer(address(this), from, address(0), amount);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
        }

        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier onlyStrategy() {
        if (msg.sender != address(strategy)) revert NotStrategyAdmin();
        _;
    }

    /**
     * @notice Adds a new operation hook to the end of the list.
     * @dev Callable only by the strategy contract.
     * @param newHookAddress The address of the new hook contract to add.
     */
    function addOperationHook(address newHookAddress) external onlyStrategy {
        if (newHookAddress == address(0)) revert HookAddressZero();
        // Consider adding a check to prevent duplicate hook additions if desired.
        operationHooks.push(IOperationHook(newHookAddress));
        emit OperationHookAdded(newHookAddress, operationHooks.length - 1);
    }

    /**
     * @notice Reorders the existing operation hooks.
     * @dev Callable only by the strategy contract. The newOrderIndices array must be a permutation
     *      of the current hook indices (0 to length-1).
     * @param newOrderIndices An array where newOrderIndices[i] specifies the OLD index of the hook
     *                        that should now be at NEW position i.
     */
    function reorderOperationHooks(uint256[] calldata newOrderIndices) external onlyStrategy {
        uint256 numHooks = operationHooks.length;
        if (newOrderIndices.length != numHooks) revert ReorderInvalidLength();

        IOperationHook[] memory reorderedHooks = new IOperationHook[](numHooks);
        bool[] memory indexSeen = new bool[](numHooks);

        for (uint256 i = 0; i < numHooks; i++) {
            uint256 oldIndex = newOrderIndices[i];
            if (oldIndex >= numHooks) revert ReorderIndexOutOfBounds();
            if (indexSeen[oldIndex]) revert ReorderDuplicateIndex();

            reorderedHooks[i] = operationHooks[oldIndex];
            indexSeen[oldIndex] = true;
        }

        operationHooks = reorderedHooks;
        emit OperationHooksReordered(newOrderIndices);
    }
}