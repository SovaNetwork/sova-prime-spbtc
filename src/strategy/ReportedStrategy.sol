// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BasicStrategy} from "./BasicStrategy.sol";
import {BaseReporter} from "../reporter/BaseReporter.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/**
 * @title ReportedStrategy
 * @notice A strategy contract that reports its underlying asset balance through an external oracle using price per share
 */
contract ReportedStrategy is BasicStrategy {
    using FixedPointMathLib for uint256;
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Optional cache for the last reported balance
    uint256 public lastReportedBalance;
    uint256 public lastReportTimestamp;

    // The reporter contract
    BaseReporter public reporter;


    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/

    // Errors
    error InvalidReporter();

    // Events
    event SetReporter(address indexed reporter);

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the strategy
     * @param name_ The name of the strategy
     * @param symbol_ The symbol of the strategy
     * @param roleManager_ The role manager address
     * @param manager_ The manager address
     * @param asset_ The asset address
     * @param assetDecimals_ The asset decimals
     * @param initData Initialization data
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public virtual override {
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, initData);

        address reporter_ = abi.decode(initData, (address));
        if (reporter_ == address(0)) revert InvalidReporter();
        reporter = BaseReporter(reporter_);

        emit SetReporter(reporter_);
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view override returns (uint256) {
        uint256 _pricePerShare = abi.decode(reporter.report(), (uint256));
        uint256 totalSupply = ERC20(sToken).totalSupply();

        // Calculate total assets: pricePerShare * totalSupply / 1e18
        return _pricePerShare.mulWad(totalSupply);
    }

    /**
     * @notice Get the current price per share from the reporter
     * @return The price per share in 18 decimal format
     */
    function pricePerShare() external view returns (uint256) {
        return abi.decode(reporter.report(), (uint256));
    }


    /**
     * @notice Set the reporter contract
     * @param _reporter The new reporter contract
     */
    function setReporter(address _reporter) external onlyManager {
        if (_reporter == address(0)) revert InvalidReporter();

        reporter = BaseReporter(_reporter);

        emit SetReporter(_reporter);
    }


}
