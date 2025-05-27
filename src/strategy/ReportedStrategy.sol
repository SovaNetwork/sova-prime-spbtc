// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

    // Price adjustment for edge cases (can be positive or negative)
    int256 public priceAdjustment;
    
    // Address of the tRWA token (needed for totalSupply)
    address public tRWAToken;

    /*//////////////////////////////////////////////////////////////
                            EVENTS & ERRORS
    //////////////////////////////////////////////////////////////*/

    // Errors
    error InvalidReporter();

    // Events
    event SetReporter(address indexed reporter);
    event SetTRWAToken(address indexed tRWAToken);
    event PriceAdjustmentSet(int256 adjustment);

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
     * @notice Get the balance of the strategy (deprecated - use calculateTotalAssets)
     * @return The balance of the strategy in the underlying asset
     */
    function balance() external view override returns (uint256) {
        return calculateTotalAssets();
    }

    /**
     * @notice Get the current price per share from the reporter
     * @return The price per share in 18 decimal format
     */
    function pricePerShare() external view returns (uint256) {
        return abi.decode(reporter.report(), (uint256));
    }

    /**
     * @notice Calculate total assets based on price per share and total supply
     * @return The total assets in the underlying asset decimals
     */
    function calculateTotalAssets() public view returns (uint256) {
        if (tRWAToken == address(0)) {
            // Fallback to reporter if tRWA token not set yet
            return abi.decode(reporter.report(), (uint256));
        }
        
        uint256 _pricePerShare = abi.decode(reporter.report(), (uint256));
        uint256 totalSupply = ERC20(tRWAToken).totalSupply();
        
        // Calculate base total assets: pricePerShare * totalSupply / 1e18
        uint256 baseAssets = _pricePerShare.mulWad(totalSupply);
        
        // Apply any price adjustments
        if (priceAdjustment >= 0) {
            return baseAssets + uint256(priceAdjustment);
        } else {
            uint256 adjustment = uint256(-priceAdjustment);
            return baseAssets > adjustment ? baseAssets - adjustment : 0;
        }
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

    /**
     * @notice Set the tRWA token address
     * @param _tRWAToken The tRWA token contract address
     */
    function setTRWAToken(address _tRWAToken) external onlyManager {
        tRWAToken = _tRWAToken;
        emit SetTRWAToken(_tRWAToken);
    }

    /**
     * @notice Set price adjustment for edge cases
     * @param adjustment The adjustment amount (can be positive or negative)
     */
    function setPriceAdjustment(int256 adjustment) external onlyManager {
        priceAdjustment = adjustment;
        emit PriceAdjustmentSet(adjustment);
    }
}
