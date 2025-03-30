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
    string public immutable symbol;
    string public immutable name;
    address public immutable asset;

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
        string memory name_,
        string memory symbol_,
        address asset_,
        address strategy_,
        address rules_
    ) {
        // Validate configuration parameters
        if (asset == address(0)) revert InvalidAddress();
        if (strategy == address(0)) revert InvalidAddress();
        if (rules == address(0)) revert InvalidAddress();

        name = name_;
        symbol = symbol_;
        asset = asset_;

        strategy = IStrategy(strategy);
        rules = IRules(rules);

        // TODO: Stronger deploy-time coupling between strategy and asset
        //          - Potentially have strategy deploy the asset
        if (strategy.asset() != asset) revert AssetMismatch();
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
        rules.evaluateDeposit(address(this), by, assets, to);

        SafeTransferLib.safeTransferFrom(asset(), by, address(this), assets);
        _mint(to, shares);

        emit Deposit(by, to, assets, shares);
    }


    /**
     * @notice Withdraw assets from the token
     * @param shares Amount of shares to withdraw
     * @param receiver Address of the receiver
     * @param owner Address of the owner
     */
    function _withdraw(address by, address to, address owner, uint256 assets, uint256 shares) internal override {
       rules.evaluateWithdraw(address(this), by, assets, to, owner);

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