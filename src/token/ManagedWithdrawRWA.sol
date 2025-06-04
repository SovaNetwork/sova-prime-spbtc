// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {tRWA} from "./tRWA.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IHook} from "../hooks/IHook.sol";

/**
 * @title ManagedWithdrawRWA
 * @notice Extension of tRWA that implements manager-initiated withdrawals
 */
contract ManagedWithdrawRWA is tRWA {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error UseRedeem();
    error InvalidArrayLengths();
    error InsufficientOutputAssets();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param asset_ Asset address
     * @param assetDecimals_ Decimals of the asset token
     * @param strategy_ Strategy address
     */
    constructor(string memory name_, string memory symbol_, address asset_, uint8 assetDecimals_, address strategy_)
        tRWA(name_, symbol_, asset_, assetDecimals_, strategy_)
    {}

    /*//////////////////////////////////////////////////////////////
                            REDEMPTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeem shares from the strategy with minimum assets check
     * @param shares The amount of shares to redeem
     * @param to The address to send the assets to
     * @param owner The owner of the shares
     * @param minAssets The minimum amount of assets to receive
     * @return assets The amount of assets received
     */
    function redeem(uint256 shares, address to, address owner, uint256 minAssets)
        public
        onlyStrategy
        returns (uint256 assets)
    {
        if (shares > maxRedeem(owner)) revert RedeemMoreThanMax();
        assets = previewRedeem(shares);

        if (assets < minAssets) revert InsufficientOutputAssets();

        // Collect assets from strategy
        _collect(assets);

        // User must token-approve strategy for withdrawal
        _withdraw(strategy, to, owner, assets, shares);
    }

    /**
     * @notice Process a batch of user-requested withdrawals with minimum assets check
     * @param shares The amount of shares to redeem
     * @param to The address to send the assets to
     * @param owner The owner of the shares
     * @param minAssets The minimum amount of assets for each withdrawal
     * @return assets The amount of assets received
     */
    function batchRedeemShares(
        uint256[] calldata shares,
        address[] calldata to,
        address[] calldata owner,
        uint256[] calldata minAssets
    ) external onlyStrategy nonReentrant returns (uint256[] memory assets) {
        // Validate array lengths
        uint256 len = shares.length;
        if (len != to.length || len != owner.length || len != minAssets.length) {
            revert InvalidArrayLengths();
        }

        // Prepare memory array and accumulate total assets required
        assets = new uint256[](len);
        uint256 totalAssets;

        for (uint256 i; i < len; ++i) {
            // Validate share amount for each owner
            if (shares[i] > maxRedeem(owner[i])) revert RedeemMoreThanMax();

            uint256 amt = previewRedeem(shares[i]);
            if (amt < minAssets[i]) revert InsufficientOutputAssets();

            assets[i] = amt;
            totalAssets += amt;
        }

        // Pull all assets from the strategy in a single transfer
        _collect(totalAssets);

        // Cache the OP_WITHDRAW hooks once to save gas / avoid stack depth issues
        HookInfo[] storage opHooks = operationHooks[OP_WITHDRAW];

        // Execute each individual withdrawal (includes hooks)
        for (uint256 i; i < len; ++i) {
            uint256 userShares = shares[i];
            uint256 userAssets = assets[i];
            address recipient = to[i];
            address shareOwner = owner[i];

            // Call hooks (same logic as in _withdraw)
            for (uint256 j; j < opHooks.length; ++j) {
                IHook.HookOutput memory hookOut =
                    opHooks[j].hook.onBeforeWithdraw(address(this), strategy, userAssets, recipient, shareOwner);
                if (!hookOut.approved) revert HookCheckFailed(hookOut.reason);
                opHooks[j].hasProcessedOperations = true;
            }

            // Accounting and transfers (mirrors _withdraw logic sans nonReentrant)
            if (strategy != shareOwner) _spendAllowance(shareOwner, strategy, userShares);
            _beforeWithdraw(userAssets, userShares);
            _burn(shareOwner, userShares);

            SafeTransferLib.safeTransfer(asset(), recipient, userAssets);
            emit Withdraw(strategy, recipient, shareOwner, userAssets, userShares);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw assets from the strategy - must be called by the manager
     * @dev Use redeem instead - all accounting is share-based
     * @return shares The amount of shares burned
     */
    function withdraw(uint256, address, address) public view override onlyStrategy returns (uint256) {
        revert UseRedeem();
    }

    /**
     * @notice Redeem shares from the strategy - must be called by the manager
     * @param shares The amount of shares to redeem
     * @param to The address to send the assets to
     * @param owner The owner of the shares
     * @return assets The amount of assets received
     */
    function redeem(uint256 shares, address to, address owner) public override onlyStrategy returns (uint256 assets) {
        if (shares > maxRedeem(owner)) revert RedeemMoreThanMax();
        assets = previewRedeem(shares);

        // Collect assets from strategy
        _collect(assets);

        // User must token-approve strategy for withdrawal
        _withdraw(strategy, to, owner, assets, shares);
    }

    /**
     * @notice Override _withdraw to skip transferAssets since we already collected
     * @param by Address initiating the withdrawal
     * @param to Address receiving the assets
     * @param owner Address that owns the shares
     * @param assets Amount of assets to withdraw
     * @param shares Amount of shares to burn
     */
    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares)
        internal
        override
        nonReentrant
    {
        if (by != owner) _spendAllowance(owner, by, shares);
        _beforeWithdraw(assets, shares);
        _burn(owner, shares);

        // Call hooks after state changes but before final transfer
        HookInfo[] storage opHooks = operationHooks[OP_WITHDRAW];
        for (uint256 i = 0; i < opHooks.length;) {
            IHook.HookOutput memory hookOutput = opHooks[i].hook.onBeforeWithdraw(address(this), by, assets, to, owner);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
            // Mark hook as having processed operations
            opHooks[i].hasProcessedOperations = true;

            unchecked {
                ++i;
            }
        }

        // Transfer the assets to the recipient
        SafeTransferLib.safeTransfer(asset(), to, assets);

        emit Withdraw(by, to, owner, assets, shares);
    }
}
