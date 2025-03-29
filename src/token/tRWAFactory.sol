// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {NavOracle} from "./NavOracle.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title tRWAFactory
 * @notice Factory contract for deploying new tRWA tokens
 */
contract tRWAFactory is Ownable {
    address public admin;

    // Registries for approved contracts
    mapping(address => bool) public rules;
    mapping(address => bool) public assets;

    address[] public allTokens;

    // Events
    event TokenDeployed(address indexed token, string name, string symbol);
    event TransferApprovalApproved(address indexed module, bool approved);
    event OracleApproved(address indexed oracle, bool approved);
    event SubscriptionManagerApproved(address indexed manager, bool approved);
    event UnderlyingAssetApproved(address indexed asset, bool approved);

    // Errors
    error InvalidAddress();
    error UnapprovedOracle();
    error UnapprovedSubscriptionManager();
    error UnapprovedUnderlyingAsset();
    error UnapprovedTransferApproval();

    /**
     * @notice Contract constructor
     */
    constructor() {
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Deploy a new tRWA token
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _oracle Oracle to use for this token
     * @param _subscriptionManager Subscription manager to use for this token
     * @param _underlyingAsset Underlying asset to use for this token
     * @param _transferApproval Transfer approval module to use for this token (can be address(0) if not needed)
     * @return token Address of the deployed token
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _subscriptionManager,
        address _underlyingAsset,
        address _transferApproval
    ) external onlyOwner returns (address) {
        if (!approvedOracles[_oracle]) revert UnapprovedOracle();
        if (!approvedSubscriptionManagers[_subscriptionManager]) revert UnapprovedSubscriptionManager();
        if (!approvedUnderlyingAssets[_underlyingAsset]) revert UnapprovedUnderlyingAsset();
        if (!approvedTransferApprovals[_transferApproval]) revert UnapprovedTransferApproval();

        // Create configuration struct
        ItRWA.ConfigurationStruct memory config = ItRWA.ConfigurationStruct({
            admin: owner(),
            priceAuthority: _oracle,
            subscriptionManager: _subscriptionManager,
            underlyingAsset: _underlyingAsset
        });

        // Deploy new tRWA token
        tRWA newToken = new tRWA(
            _name,
            _symbol,
            config
        );

        // Register token in the factory
        address tokenAddr = address(newToken);
        isRegisteredToken[tokenAddr] = true;
        allTokens.push(tokenAddr);

        emit TokenDeployed(tokenAddr, _name, _symbol);

        return tokenAddr;
    }

    /**
     * @notice Approve or disapprove a transfer approval module
     * @param _transferApproval Address of the transfer approval module
     * @param _approved Whether to approve or disapprove
     */
    function setTransferApprovalApproval(address _transferApproval, bool _approved) external onlyOwner {
        if (_transferApproval == address(0)) revert InvalidAddress();

        approvedTransferApprovals[_transferApproval] = _approved;

        emit TransferApprovalApproved(_transferApproval, _approved);
    }

    /**
     * @notice Approve or disapprove an oracle
     * @param _oracle Address of the oracle
     * @param _approved Whether to approve or disapprove
     */
    function setOracleApproval(address _oracle, bool _approved) external onlyOwner {
        if (_oracle == address(0)) revert InvalidAddress();

        approvedOracles[_oracle] = _approved;

        emit OracleApproved(_oracle, _approved);
    }

    /**
     * @notice Approve or disapprove a subscription manager
     * @param _subscriptionManager Address of the subscription manager
     * @param _approved Whether to approve or disapprove
     */
    function setSubscriptionManagerApproval(address _subscriptionManager, bool _approved) external onlyOwner {
        if (_subscriptionManager == address(0)) revert InvalidAddress();

        approvedSubscriptionManagers[_subscriptionManager] = _approved;

        emit SubscriptionManagerApproved(_subscriptionManager, _approved);
    }

    /**
     * @notice Approve or disapprove an underlying asset
     * @param _underlyingAsset Address of the underlying asset
     * @param _approved Whether to approve or disapprove
     */
    function setUnderlyingAssetApproval(address _underlyingAsset, bool _approved) external onlyOwner {
        if (_underlyingAsset == address(0)) revert InvalidAddress();

        approvedUnderlyingAssets[_underlyingAsset] = _approved;

        emit UnderlyingAssetApproved(_underlyingAsset, _approved);
    }

    /**
     * @notice Check if a transfer approval module is approved
     * @param _transferApproval Address of the transfer approval module
     * @return approved Whether the transfer approval module is approved
     */
    function isTransferApprovalApproved(address _transferApproval) external view returns (bool) {
        return approvedTransferApprovals[_transferApproval];
    }

    /**
     * @notice Check if an oracle is approved
     * @param _oracle Address of the oracle
     * @return approved Whether the oracle is approved
     */
    function isOracleApproved(address _oracle) external view returns (bool) {
        return approvedOracles[_oracle];
    }

    /**
     * @notice Check if a subscription manager is approved
     * @param _subscriptionManager Address of the subscription manager
     * @return approved Whether the subscription manager is approved
     */
    function isSubscriptionManagerApproved(address _subscriptionManager) external view returns (bool) {
        return approvedSubscriptionManagers[_subscriptionManager];
    }

    /**
     * @notice Check if an underlying asset is approved
     * @param _underlyingAsset Address of the underlying asset
     * @return approved Whether the underlying asset is approved
     */
    function isUnderlyingAssetApproved(address _underlyingAsset) external view returns (bool) {
        return approvedUnderlyingAssets[_underlyingAsset];
    }

    /**
     * @notice Get all registered tokens
     * @return tokens Array of registered token addresses
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Get the number of registered tokens
     * @return count Number of registered tokens
     */
    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
}