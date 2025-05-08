// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GatedMintRWA} from "../token/GatedMintRWA.sol";
import {ReportedStrategy} from "./ReportedStrategy.sol";
import {BaseReporter} from "../reporter/BaseReporter.sol";
/**
 * @title GatedMintReportedStrategy
 * @notice Extension of ReportedStrategy that deploys and configures GatedMintRWA tokens
 */
contract GatedMintReportedStrategy is ReportedStrategy {
    /**
     * @notice Initialize the strategy implementation
     */
    constructor(address _roleManager) ReportedStrategy(_roleManager) {}

    /**
     * @notice Initialize the strategy with GatedMintRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param initData Additional initialization data (unused)
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public override {
        // Prevent re-initialization
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        // Check required parameters
        if (manager_ == address(0)) revert InvalidAddress();
        if (asset_ == address(0)) revert InvalidAddress();

        // Set up strategy configuration
        manager = manager_;
        asset = asset_;

        // Deploy GatedMintRWA token
        GatedMintRWA newToken = new GatedMintRWA(
            name_,
            symbol_,
            asset,
            assetDecimals_,
            address(this)
        );

        sToken = address(newToken);

        address reporter_ = abi.decode(initData, (address));
        if (reporter_ == address(0)) revert InvalidReporter();
        reporter = BaseReporter(reporter_);

        emit SetReporter(reporter_);
        emit StrategyInitialized(address(0), manager, asset, sToken);
    }
}