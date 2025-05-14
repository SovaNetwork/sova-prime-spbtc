// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IStrategy} from "../strategy/IStrategy.sol";

/**
 * @title ManagedWithdrawRWA
 * @notice Extension of tRWA that implements manager-initiated withdrawals
 */
contract ManagedWithdrawRWA is tRWA {
    error NotManager();
    error UseRedeem();
    error InvalidArrayLengths();
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
    function withdraw(uint256, address, address) public view override onlyManager returns (uint256) {
       revert UseRedeem();
    }

    /**
     * @notice Redeem shares from the strategy - must be called by the manager
     * @param shares The amount of shares to redeem
     * @param to The address to send the assets to
     * @param owner The owner of the shares
     * @return assets The amount of assets received
     */
    function redeem(uint256 shares, address to, address owner) public override onlyManager returns (uint256 assets) {
        if (shares > maxRedeem(owner)) revert RedeemMoreThanMax();
        assets = previewRedeem(shares);

        // Collect shares from strategy
        _collect(assets);

        // User must token-approve strategy for withdrawal
        _withdraw(strategy, to, owner, assets, shares);
    }

    function batchRedeemShares(
        uint256[] calldata shares,
        address[] calldata to,
        address[] calldata owner
    ) external onlyManager returns (uint256[] memory assets) {
        // Validate array lengths match
        if (shares.length != to.length || to.length != owner.length) {
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

        for (uint256 i = 0; i < shares.length; i++) {
            uint256 recipientAssets = (shares[i] * totalAssets) / totalShares;

            if (strategy != owner[i]) _spendAllowance(owner[i], strategy, shares[i]);
            _beforeWithdraw(assets[i], shares[i]);
            _burn(owner[i], shares[i]);

            SafeTransferLib.safeTransfer(asset(), to[i], recipientAssets);

            emit Withdraw(strategy, to[i], owner[i], recipientAssets, shares[i]);
        }
    }

    /**
     * @notice Collect assets from the strategy
     * @param assets The amount of assets to collect
     */
    function _collect(uint256 assets) internal {
        SafeTransferLib.safeTransferFrom(asset(), strategy, address(this), assets);
    }

    /**
     * @notice Modifier to check if the caller is the strategy manager
     */
    modifier onlyManager() {
        if (msg.sender != IStrategy(strategy).manager()) revert NotManager();
        _;
    }
}