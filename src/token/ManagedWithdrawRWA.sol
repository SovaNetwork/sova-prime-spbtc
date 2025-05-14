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
     * @param assets The amount of assets to withdraw
     * @param to The address to send the assets to
     * @param owner The owner of the assets
     * @return shares The amount of shares burned
     */
    function withdraw(uint256 assets, address to, address owner) public override onlyManager returns (uint256 shares) {
        if (assets > maxWithdraw(owner)) revert WithdrawMoreThanMax();
        shares = previewWithdraw(assets);

        // Collect assets from strategy
        _collect(assets);

        // User must token-approve strategy for withdrawal
        _withdraw(strategy, to, owner, assets, shares);
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