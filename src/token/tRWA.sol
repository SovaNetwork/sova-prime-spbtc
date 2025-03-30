// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IRules} from "../rules/IRules.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {ItRWA} from "./ItRWA.sol";


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
    IStrategy public strategy;
    IRules public immutable rules;

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

        strategy = IStrategy(strategy);
        rules = IRules(rules);

        // TODO: Stronger deploy-time coupling between strategy and asset
        //          - Potentially have strategy deploy the asset
        if (strategy.asset() != _asset) revert AssetMismatch();
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

       if (!result.approved) revert RuleCheckFailed(result.reason);

       if (by != owner) {
           _spendAllowance(owner, by, shares);
       }

       if (shares > balanceOf(owner))
           revert WithdrawMoreThanMax();

       _burn(owner, shares);

       // TODO: Do not transfer any asset here, for now

       emit Withdraw(by, to, owner, assets, shares);
    }
}