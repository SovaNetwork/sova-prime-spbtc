// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IHook} from "../hooks/IHook.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {ItRWA} from "./ItRWA.sol";

import {Conduit} from "../conduit/Conduit.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {IRegistry} from "../registry/IRegistry.sol";

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
    error HookCheckFailed(string reason);
    error NotStrategyAdmin();
    error HookAddressZero();
    error ReorderInvalidLength();
    error ReorderIndexOutOfBounds();
    error ReorderDuplicateIndex();

    // Operation type identifiers
    bytes32 public constant OP_DEPOSIT = keccak256("DEPOSIT_OPERATION");
    bytes32 public constant OP_WITHDRAW = keccak256("WITHDRAW_OPERATION");
    bytes32 public constant OP_TRANSFER = keccak256("TRANSFER_OPERATION");

    // Internal storage for token metadata
    string private _symbol;
    string private _name;
    address private immutable _asset;
    uint8 private immutable _assetDecimals;

    // Logic contracts
    address public immutable strategy;
    mapping(bytes32 => IHook[]) public operationHooks;

    // Events for withdrawal queueing
    event WithdrawalQueued(address indexed user, uint256 assets, uint256 shares);
    event HookAdded(bytes32 indexed operationType, address indexed hookAddress, uint256 index);
    event HookRemoved(bytes32 indexed operationType, address indexed hookAddress);
    event HooksReordered(bytes32 indexed operationType, uint256[] newIndices);

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Decimals of the asset token
     * @param strategy_ Strategy address
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint8 assetDecimals_,
        address strategy_
    ) {
        // Validate configuration parameters
        if (asset_ == address(0)) revert InvalidAddress();
        if (strategy_ == address(0)) revert InvalidAddress();

        _name = name_;
        _symbol = symbol_;
        _asset = asset_;
        _assetDecimals = assetDecimals_;
        strategy = strategy_;
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
    function asset() public view virtual override(ERC4626, ItRWA) returns (address) {
        return _asset;
    }

    /**
     * @notice Returns the total amount of the underlying asset managed by the Vault.
     * @dev This value is expected by the base ERC4626 implementation to be in terms of asset's native decimals.
     * @return Total assets in terms of _asset
     */
    function totalAssets() public view override returns (uint256) {
        return IStrategy(strategy).balance(); // Returns balance in `_assetDecimals`
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
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit assets into the token
     * @param by Address of the sender
     * @param to Address of the receiver
     * @param assets Amount of assets to deposit
     * @param shares Amount of shares to mint
     */
    function _deposit(address by, address to, uint256 assets, uint256 shares) internal virtual override {
        IHook[] storage opHooks = operationHooks[OP_DEPOSIT];
        for (uint i = 0; i < opHooks.length; i++) {
            IHook.HookOutput memory hookOutput = opHooks[i].onBeforeDeposit(address(this), by, assets, to);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
        }

        Conduit(
            IRegistry(RoleManaged(strategy).registry()).conduit()
        ).collectDeposit(asset(), by, address(this), assets);

        _mint(to, shares);

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
       IHook[] storage opHooks = operationHooks[OP_WITHDRAW];
       for (uint256 i = 0; i < opHooks.length; i++) {
            IHook.HookOutput memory hookOutput = opHooks[i].onBeforeWithdraw(address(this), by, assets, to, owner);
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
        // Hooks for burn (transfer to address(0)) are handled by _beforeTokenTransfer
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier onlyStrategy() {
        if (msg.sender != strategy) revert NotStrategyAdmin();
        _;
    }

    /**
     * @notice Adds a new operation hook to the end of the list for a specific operation type.
     * @dev Callable only by the strategy contract.
     * @param operationType The type of operation this hook applies to (e.g., OP_DEPOSIT).
     * @param newHookAddress The address of the new hook contract to add.
     */
    function addOperationHook(bytes32 operationType, address newHookAddress) external onlyStrategy {
        if (newHookAddress == address(0)) revert HookAddressZero();
        // Consider adding a check to prevent duplicate hook additions if desired.
        operationHooks[operationType].push(IHook(newHookAddress));
        emit HookAdded(operationType, newHookAddress, operationHooks[operationType].length - 1);
    }

    /**
     * @notice Reorders the existing operation hooks for a specific operation type.
     * @dev Callable only by the strategy contract. The newOrderIndices array must be a permutation
     *      of the current hook indices (0 to length-1) for the given operation type.
     * @param operationType The type of operation for which hooks are being reordered.
     * @param newOrderIndices An array where newOrderIndices[i] specifies the OLD index of the hook
     *                        that should now be at NEW position i.
     */
    function reorderOperationHooks(bytes32 operationType, uint256[] calldata newOrderIndices) external onlyStrategy {
        IHook[] storage opTypeHooks = operationHooks[operationType];
        uint256 numHooks = opTypeHooks.length;
        if (newOrderIndices.length != numHooks) revert ReorderInvalidLength();

        IHook[] memory reorderedHooks = new IHook[](numHooks);
        bool[] memory indexSeen = new bool[](numHooks);

        for (uint256 i = 0; i < numHooks; i++) {
            uint256 oldIndex = newOrderIndices[i];
            if (oldIndex >= numHooks) revert ReorderIndexOutOfBounds();
            if (indexSeen[oldIndex]) revert ReorderDuplicateIndex();

            reorderedHooks[i] = opTypeHooks[oldIndex];
            indexSeen[oldIndex] = true;
        }

        operationHooks[operationType] = reorderedHooks;
        emit HooksReordered(operationType, newOrderIndices);
    }

    /**
     * @notice Gets all registered hook addresses for a specific operation type.
     * @param operationType The type of operation.
     * @return An array of hook contract addresses.
     */
    function getHooksForOperation(bytes32 operationType) external view returns (address[] memory) {
        IHook[] storage opTypeHooks = operationHooks[operationType];
        address[] memory hookAddresses = new address[](opTypeHooks.length);
        for (uint i = 0; i < opTypeHooks.length; i++) {
            hookAddresses[i] = address(opTypeHooks[i]);
        }
        return hookAddresses;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 HOOK OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hook that is called before any token transfer, including mints and burns.
     * We use this to apply OP_TRANSFER hooks.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount); // Call to parent ERC20/ERC4626 _beforeTokenTransfer if it exists

        IHook[] storage opHooks = operationHooks[OP_TRANSFER];
        if (opHooks.length > 0) { // Optimization to save gas if no hooks registered for OP_TRANSFER
            for (uint i = 0; i < opHooks.length; i++) {
                IHook.HookOutput memory hookOutput = opHooks[i].onBeforeTransfer(address(this), from, to, amount);
                if (!hookOutput.approved) {
                    revert HookCheckFailed(hookOutput.reason);
                }
            }
        }
    }
}