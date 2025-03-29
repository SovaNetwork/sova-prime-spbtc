// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";
import {ItRWAHook} from "../interfaces/ItRWAHook.sol";
import {IRuleEngine} from "../interfaces/IRuleEngine.sol";

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) inheriting ERC4626 standard
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC4626, OwnableRoles, ItRWA {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    // Internal storage for token metadata
    uint256 constant DECIMALS = 18;
    string internal immutable _name;
    string internal immutable _symbol;
    ERC20 internal _asset;

    // Logic contracts
    IStrategy public strategy;
    IRules public immutable rules;

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param config Configuration struct with all deployment parameters
     */
    constructor(
        string memory name,
        string memory symbol,
        address asset,
        address strategy,
        address rules
    ) {
        // Validate configuration parameters
        if (asset == address(0)) revert InvalidAddress();
        if (strategy == address(0)) revert InvalidAddress();
        if (rules == address(0)) revert InvalidAddress();

        _name = name;
        _symbol = symbol;
        _asset = ERC20(asset);

        strategy = IStrategy(strategy);
        rules = IRules(rules);

        if (strategy.asset() != asset) revert AssetMismatch();
    }

    /**
     * @notice Returns the name of the token
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the decimals places of the token
     */
    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Returns the underlying asset address
     * @return Address of the underlying ERC20 token
     */
    function asset() public view virtual override returns (address) {
        return _asset;
    }

    /**
     * @notice Returns the total assets of the strategy
     * @return Total assets in terms of _asset
     */
    function totalAssets() public view override returns (uint256) {
        return strategy.balance();
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new hook
     * @param hook Address of the hook to add
     * @return hookId ID of the added hook
     */
    function addHook(address hook) external onlyOwnerOrRoles(ADMIN_ROLE) returns (uint256) {
        if (hook == address(0)) revert InvalidAddress();

        uint256 hookId = nextHookId;
        hooks[hookId] = HookInfo({
            hookAddress: hook,
            active: true
        });
        nextHookId++;

        emit HookAdded(hookId, hook);
        return hookId;
    }

    /**
     * @notice Remove a hook
     * @param hookId ID of the hook to remove
     */
    function removeHook(uint256 hookId) external onlyOwnerOrRoles(ADMIN_ROLE) {
        if (hooks[hookId].hookAddress == address(0)) revert InvalidAddress();

        delete hooks[hookId];

        emit HookRemoved(hookId);
    }

    /**
     * @notice Set the active status of a hook
     * @param hookId ID of the hook
     * @param active Whether the hook is active
     */
    function setHookStatus(uint256 hookId, bool active) external onlyOwnerOrRoles(ADMIN_ROLE) {
        if (hooks[hookId].hookAddress == address(0)) revert InvalidAddress();

        hooks[hookId].active = active;

        emit HookStatusChanged(hookId, active);
    }

    /**
     * @notice Get information about a hook
     * @param hookId ID of the hook
     * @return hookAddress Address of the hook
     * @return active Whether the hook is active
     */
    function getHook(uint256 hookId) external view returns (address hookAddress, bool active) {
        return (hooks[hookId].hookAddress, hooks[hookId].active);
    }

    /**
     * @notice Execute pre-operation hooks
     * @param operation Identifier for the operation (1=deposit, 2=mint, 3=withdraw, 4=redeem, 5=transfer)
     * @param data Encoded parameters for the operation
     * @return Whether all hooks passed
     */
    function _executePreHooks(uint8 operation, bytes memory data) internal returns (bool) {
        for (uint256 i = 1; i < nextHookId; i++) {
            HookInfo memory hookInfo = hooks[i];
            if (hookInfo.hookAddress != address(0) && hookInfo.active) {
                bool success;

                if (operation == 1) { // deposit
                    (address user, uint256 assets, address receiver) = abi.decode(data, (address, uint256, address));
                    success = ItRWAHook(hookInfo.hookAddress).beforeDeposit(user, assets, receiver);
                } else if (operation == 2) { // mint
                    (address user, uint256 shares, address receiver) = abi.decode(data, (address, uint256, address));
                    success = ItRWAHook(hookInfo.hookAddress).beforeMint(user, shares, receiver);
                } else if (operation == 3) { // withdraw
                    (address user, uint256 assets, address receiver, address owner) = abi.decode(data, (address, uint256, address, address));
                    success = ItRWAHook(hookInfo.hookAddress).beforeWithdraw(user, assets, receiver, owner);
                } else if (operation == 4) { // redeem
                    (address user, uint256 shares, address receiver, address owner) = abi.decode(data, (address, uint256, address, address));
                    success = ItRWAHook(hookInfo.hookAddress).beforeRedeem(user, shares, receiver, owner);
                } else if (operation == 5) { // transfer
                    (address from, address to, uint256 value) = abi.decode(data, (address, address, uint256));
                    success = ItRWAHook(hookInfo.hookAddress).beforeTransfer(from, to, value);
                }

                if (!success) {
                    revert HookReverted(i);
                }
            }
        }

        return true;
    }

    /**
     * @notice Execute post-operation hooks
     * @param operation Identifier for the operation (1=deposit, 2=mint, 3=withdraw, 4=redeem, 5=transfer)
     * @param data Encoded parameters for the operation
     */
    function _executePostHooks(uint8 operation, bytes memory data) internal {
        for (uint256 i = 1; i < nextHookId; i++) {
            HookInfo memory hookInfo = hooks[i];
            if (hookInfo.hookAddress != address(0) && hookInfo.active) {
                if (operation == 1) { // deposit
                    (address user, uint256 assets, address receiver, uint256 shares) = abi.decode(data, (address, uint256, address, uint256));
                    try ItRWAHook(hookInfo.hookAddress).afterDeposit(user, assets, receiver, shares) {} catch {}
                } else if (operation == 2) { // mint
                    (address user, uint256 shares, address receiver, uint256 assets) = abi.decode(data, (address, uint256, address, uint256));
                    try ItRWAHook(hookInfo.hookAddress).afterMint(user, shares, receiver, assets) {} catch {}
                } else if (operation == 3) { // withdraw
                    (address user, uint256 assets, address receiver, address owner, uint256 shares) = abi.decode(data, (address, uint256, address, address, uint256));
                    try ItRWAHook(hookInfo.hookAddress).afterWithdraw(user, assets, receiver, owner, shares) {} catch {}
                } else if (operation == 4) { // redeem
                    (address user, uint256 shares, address receiver, address owner, uint256 assets) = abi.decode(data, (address, uint256, address, address, uint256));
                    try ItRWAHook(hookInfo.hookAddress).afterRedeem(user, shares, receiver, owner, assets) {} catch {}
                } else if (operation == 5) { // transfer
                    (address from, address to, uint256 value) = abi.decode(data, (address, address, uint256));
                    try ItRWAHook(hookInfo.hookAddress).afterTransfer(from, to, value) {} catch {}
                }
            }
        }
    }

    /**
     * @notice Override _beforeTokenTransfer to add hook-based transfer approval checks
     * @dev Called before any transfer, mint, or burn
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip checks for minting and burning which are controlled by admin
        if (from != address(0) && to != address(0)) {
            if (to == address(0)) revert InvalidAddress();

            // Legacy transfer approval check
            if (transferApprovalEnabled && transferApproval != address(0)) {
                // Call checkTransferApproval which will revert with specific errors if not approved
                (bool successCall,) = transferApproval.staticcall(
                    abi.encodeWithSignature(
                        "checkTransferApproval(address,address,address,uint256)",
                        address(this),
                        from,
                        to,
                        amount
                    )
                );

                if (!successCall) {
                    // If the call failed, it means one of the specific errors was thrown
                    // We'll rethrow the same error
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
            }

            // New rules check
            if (rulesEnabled && ruleEngine != address(0)) {
                // Call checkTransfer which will revert with specific errors if not approved
                (bool successCall,) = ruleEngine.staticcall(
                    abi.encodeCall(
                        IRuleEngine.checkTransfer,
                        (from, to, amount)
                    )
                );

                if (!successCall) {
                    // If the call failed, it means one of the specific errors was thrown
                    // We'll rethrow the same error
                    assembly {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
            }

            // New hook-based transfer approval
            bytes memory data = abi.encode(from, to, amount);
            _executePreHooks(5, data);
        }
    }

    /**
     * @notice Override _afterTokenTransfer to add hook-based transfer notification
     * @dev Called after any transfer, mint, or burn
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            bytes memory data = abi.encode(from, to, amount);
            _executePostHooks(5, data);
        }
        super._afterTokenTransfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of the underlying assets managed by the vault
     * @return assets Total underlying assets in USD value (18 decimals)
     */
    function totalAssets() public view override returns (uint256 assets) {
        return totalUnderlying;
    }

    /**
     * @notice Deposit assets and mint shares to receiver
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        // Check rules before deposit if enabled
        if (rulesEnabled && ruleEngine != address(0)) {
            (bool successCall,) = ruleEngine.staticcall(
                abi.encodeCall(
                    IRuleEngine.checkDeposit,
                    (msg.sender, assets, receiver)
                )
            );

            if (!successCall) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        // Check hooks before deposit
        bytes memory preData = abi.encode(msg.sender, assets, receiver);
        _executePreHooks(1, preData);

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        // Transfer assets from the sender to this contract
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Add to pending deposits bucket
        pendingDeposits += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // Execute hooks after deposit
        bytes memory postData = abi.encode(msg.sender, assets, receiver, shares);
        _executePostHooks(1, postData);
    }

    /**
     * @notice Mint shares to receiver by depositing assets
     * @param shares Amount of shares to mint
     * @param receiver Address receiving the shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        // Check rules before mint if enabled
        if (rulesEnabled && ruleEngine != address(0)) {
            (bool successCall,) = ruleEngine.staticcall(
                abi.encodeCall(
                    IRuleEngine.checkMint,
                    (msg.sender, shares, receiver)
                )
            );

            if (!successCall) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        // Check hooks before mint
        bytes memory preData = abi.encode(msg.sender, shares, receiver);
        _executePreHooks(2, preData);

        assets = previewMint(shares);
        if (assets == 0) revert ZeroAssets();

        // Transfer assets from the sender to this contract
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Add to pending deposits bucket
        pendingDeposits += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // Execute hooks after mint
        bytes memory postData = abi.encode(msg.sender, shares, receiver, assets);
        _executePostHooks(2, postData);
    }

    /**
     * @notice Withdraw assets by burning shares
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        // Check rules before withdraw if enabled
        if (rulesEnabled && ruleEngine != address(0)) {
            (bool successCall,) = ruleEngine.staticcall(
                abi.encodeCall(
                    IRuleEngine.checkWithdraw,
                    (msg.sender, assets, receiver, owner)
                )
            );

            if (!successCall) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        // Check hooks before withdraw
        bytes memory preData = abi.encode(msg.sender, assets, receiver, owner);
        _executePreHooks(3, preData);

        shares = previewWithdraw(assets);
        if (shares == 0) revert ZeroShares();

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        if (shares > balanceOf(owner))
            revert WithdrawMoreThanMax();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        // Mark as pending withdrawal to be processed later
        // Actual transfer of assets happens when processWithdrawal is called

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Execute hooks after withdraw
        bytes memory postData = abi.encode(msg.sender, assets, receiver, owner, shares);
        _executePostHooks(3, postData);
    }

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return assets Amount of assets received
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        // Check rules before redeem if enabled
        if (rulesEnabled && ruleEngine != address(0)) {
            (bool successCall,) = ruleEngine.staticcall(
                abi.encodeCall(
                    IRuleEngine.checkRedeem,
                    (msg.sender, shares, receiver, owner)
                )
            );

            if (!successCall) {
                assembly {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        // Check hooks before redeem
        bytes memory preData = abi.encode(msg.sender, shares, receiver, owner);
        _executePreHooks(4, preData);

        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }

        if (shares > balanceOf(owner))
            revert RedeemMoreThanMax();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        // Mark as pending withdrawal to be processed later
        // Actual transfer of assets happens when processWithdrawal is called

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        // Execute hooks after redeem
        bytes memory postData = abi.encode(msg.sender, shares, receiver, owner, assets);
        _executePostHooks(4, postData);
    }
}