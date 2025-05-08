// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BasicStrategy} from "./BasicStrategy.sol";
import {GatedMintRWA} from "../token/GatedMintRWA.sol";
import {Escrow} from "../token/Escrow.sol";
import {IStrategy} from "./IStrategy.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title GatedMintRWAStrategy
 * @notice Extension of BasicStrategy that deploys and configures GatedMintRWA tokens and Escrow
 */
contract GatedMintRWAStrategy is BasicStrategy {
    // Additional state
    address public escrow;

    /**
     * @notice Event emitted when the escrow is created
     * @param escrow The address of the escrow
     */
    event EscrowCreated(address escrow);

    /**
     * @notice Initialize the strategy implementation
     */
    constructor(address _roleManager) BasicStrategy(_roleManager) {}

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

        // Create escrow contract
        Escrow newEscrow = new Escrow(
            sToken,       // GatedMintRWA token
            asset,        // Underlying asset
            address(this),// Strategy
            manager       // Manager
        );

        escrow = address(newEscrow);
        
        // Configure the token to use the escrow
        GatedMintRWA(sToken).setEscrow(escrow);

        emit StrategyInitialized(address(0), manager, asset, sToken);
        emit EscrowCreated(escrow);
    }

    /**
     * @notice Get the balance of the strategy
     * @return The balance of the strategy
     */
    function balance() external view override returns (uint256) {
        return SafeTransferLib.balanceOf(asset, address(this));
    }

    /**
     * @notice Transfer assets from the strategy to a user
     * @param user The user address
     * @param amount The amount to transfer
     */
    function transferAssets(address user, uint256 amount) external override {
        // Only callable by token, which will have verified caller permissions
        if (msg.sender != sToken) revert Unauthorized();
        
        // Call the appropriate functionality to transfer assets to the user
        SafeTransferLib.safeTransfer(asset, user, amount);
    }

    /**
     * @notice Accept a deposit in the escrow
     * @param depositId The ID of the deposit to accept
     */
    function acceptDeposit(bytes32 depositId) external onlyManager {
        Escrow(escrow).acceptDeposit(depositId);
    }

    /**
     * @notice Refund a deposit in the escrow
     * @param depositId The ID of the deposit to refund
     */
    function refundDeposit(bytes32 depositId) external onlyManager {
        Escrow(escrow).refundDeposit(depositId);
    }
}