// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ManagedWithdrawRWA} from "../token/ManagedWithdrawRWA.sol";
import {ReportedStrategy} from "./ReportedStrategy.sol";
import {BaseReporter} from "../reporter/BaseReporter.sol";
import {EIP712} from "solady/utils/EIP712.sol";

/**
 * @title ManagedWithdrawReportedStrategy
 * @notice Extension of ReportedStrategy that deploys and configures ManagedWithdrawRWA tokens
 */
contract ManagedWithdrawReportedStrategy is ReportedStrategy {

    // Custom errors
    error WithdrawalRequestExpired();
    error WithdrawRequestLapsedRound();
    error WithdrawNonceReuse();
    error WithdrawInvalidSignature();

    struct WithdrawalRequest {
        uint256 assets;
        address owner;
        uint96 nonce;
        address to;
        uint96 expirationTime;
        uint64 maxRound;
    }

    // Tracking of batch withdrawals
    uint64 public currentRound;

    // Tracking of used nonces
    mapping(address => mapping(uint96 => bool)) public usedNonces;

    /**
     * @notice Initialize the strategy with ManagedWithdrawRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param initData Additional initialization data (unused)
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
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
        _initializeRoleManager(roleManager_);

        // Deploy ManagedWithdrawRWA token
        ManagedWithdrawRWA newToken = new ManagedWithdrawRWA(
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

    /**
     * @notice Process a user-requested withdrawal
     * @param request The withdrawal request
     * @param signature The signature of the request
     * @return assets The amount of assets received
     */
    function redeem(
        WithdrawalRequest calldata request,
        bytes calldata signature
    ) external onlyManager returns (uint256 assets) {
        if (request.expirationTime < block.timestamp) revert WithdrawalRequestExpired();
        if (request.maxRound < currentRound) revert WithdrawRequestLapsedRound();
        if (usedNonces[request.owner][request.nonce]) revert WithdrawNonceReuse();


        // Verify signature
        // if (request.owner != ecrecover(keccak256(abi.encode(request)), signature)) revert WithdrawInvalidSignature();

        // Mark nonce as used
        usedNonces[request.owner][request.nonce] = true;

        // Increment round
        currentRound++;

        assets = ManagedWithdrawRWA(sToken).redeem(request.assets, request.to, request.owner);
    }
}