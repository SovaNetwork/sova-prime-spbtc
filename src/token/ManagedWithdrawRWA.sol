// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IHook} from "../hooks/IHook.sol";

/**
 * @title ManagedWithdrawRWA
 * @notice Extension of tRWA that implements manager-initiated withdrawals
 */
contract ManagedWithdrawRWA is tRWA {
    error NotManager();
    error UseRedeem();
    error InvalidArrayLengths();
    error InsufficientOutputAssets();

    uint256 private constant ONE = 1e18;
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
    ) tRWA(name_, symbol_, asset_, assetDecimals_, strategy_) {}

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
     * @notice Redeem shares from the strategy with minimum assets check
     * @param shares The amount of shares to redeem
     * @param to The address to send the assets to
     * @param owner The owner of the shares
     * @param minAssets The minimum amount of assets to receive
     * @return assets The amount of assets received
     */
    function redeem(uint256 shares, address to, address owner, uint256 minAssets) public onlyStrategy returns (uint256 assets) {
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
    ) external onlyStrategy returns (uint256[] memory assets) {
        // Validate array lengths match
        if (shares.length != to.length || to.length != owner.length || owner.length != minAssets.length) {
            revert InvalidArrayLengths();
        }

        // Calculate total assets based on the sum of all shares in the batch
        uint256 totalAssets = 0;
        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalAssets += previewRedeem(shares[i]);
            totalShares += shares[i];
        }

        // Collect assets from strategy
        _collect(totalAssets);

        assets = new uint256[](shares.length);

        // Process each withdrawal, based on prorated assets
        for (uint256 i = 0; i < shares.length; i++) {
            uint256 userShares = shares[i];
            address userOwner = owner[i];
            // Use higher precision calculation to minimize rounding errors
            uint256 scaledAssets = totalAssets * ONE;
            uint256 recipientAssets = (userShares * scaledAssets / totalShares) / ONE;
            assets[i] = recipientAssets;

            if (recipientAssets < minAssets[i]) revert InsufficientOutputAssets();

            if (strategy != userOwner) _spendAllowance(userOwner, strategy, userShares);
            _beforeWithdraw(assets[i], userShares);
            _burn(userOwner, userShares);

            SafeTransferLib.safeTransfer(asset(), to[i], recipientAssets);

            emit Withdraw(strategy, to[i], userOwner, recipientAssets, userShares);
        }
    }

    /**
     * @notice Override _withdraw to skip transferAssets since we already collected
     * @param by Address initiating the withdrawal
     * @param to Address receiving the assets
     * @param owner Address that owns the shares
     * @param assets Amount of assets to withdraw
     * @param shares Amount of shares to burn
     */
    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares) internal override {
        HookInfo[] storage opHooks = operationHooks[OP_WITHDRAW];
        for (uint256 i = 0; i < opHooks.length; i++) {
            IHook.HookOutput memory hookOutput = opHooks[i].hook.onBeforeWithdraw(address(this), by, assets, to, owner);
            if (!hookOutput.approved) {
                revert HookCheckFailed(hookOutput.reason);
            }
            // Mark hook as having processed operations
            opHooks[i].hasProcessedOperations = true;
        }

        // Standard ERC4626 withdraw flow
        if (by != owner) _spendAllowance(owner, by, shares);
        _beforeWithdraw(assets, shares);
        _burn(owner, shares);

        // Transfer the assets to the recipient
        SafeTransferLib.safeTransfer(asset(), to, assets);

        emit Withdraw(by, to, owner, assets, shares);
    }
}