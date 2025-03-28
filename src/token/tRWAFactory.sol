// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {NavOracle} from "./NavOracle.sol";
import {ItRWA} from "../interfaces/ItRWA.sol";

/**
 * @title tRWAFactory
 * @notice Factory contract for deploying new tRWA tokens
 */
contract tRWAFactory {
    address public admin;
    NavOracle public oracle;
    address public transferApproval;
    address public subscriptionManager;
    address public underlyingAsset;
    mapping(address => bool) public isRegisteredToken;
    address[] public allTokens;

    // Events
    event TokenDeployed(address indexed token, string name, string symbol, uint256 initialUnderlyingPerToken);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event TransferApprovalUpdated(address indexed oldModule, address indexed newModule);
    event SubscriptionManagerUpdated(address indexed oldManager, address indexed newManager);
    event UnderlyingAssetUpdated(address indexed oldAsset, address indexed newAsset);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidUnderlyingValue();

    /**
     * @notice Contract constructor
     * @param _oracle Address of the oracle
     * @param _subscriptionManager Address of the subscription manager
     * @param _underlyingAsset Address of the underlying asset
     */
    constructor(address _oracle, address _subscriptionManager, address _underlyingAsset) {
        if (_oracle == address(0)) revert InvalidAddress();
        if (_subscriptionManager == address(0)) revert InvalidAddress();
        if (_underlyingAsset == address(0)) revert InvalidAddress();

        admin = msg.sender;
        oracle = NavOracle(_oracle);
        subscriptionManager = _subscriptionManager;
        underlyingAsset = _underlyingAsset;
    }

    /**
     * @notice Modifier to restrict function calls to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Deploy a new tRWA token
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialUnderlyingPerToken Initial underlying value per token in USD (18 decimals)
     * @return token Address of the deployed token
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        uint256 _initialUnderlyingPerToken
    ) external onlyAdmin returns (address) {
        if (_initialUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        // Create configuration struct
        ItRWA.ConfigurationStruct memory config = ItRWA.ConfigurationStruct({
            admin: admin,
            priceAuthority: address(oracle),
            subscriptionManager: subscriptionManager,
            underlyingAsset: underlyingAsset,
            initialUnderlyingPerToken: _initialUnderlyingPerToken
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

        // Register token in the oracle
        oracle.setTokenStatus(tokenAddr, true);

        emit TokenDeployed(tokenAddr, _name, _symbol, _initialUnderlyingPerToken);

        return tokenAddr;
    }

    /**
     * @notice Update the admin address
     * @param _newAdmin Address of the new admin
     */
    function updateAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAddress();

        address oldAdmin = admin;
        admin = _newAdmin;

        emit AdminUpdated(oldAdmin, _newAdmin);
    }

    /**
     * @notice Update the oracle address
     * @param _newOracle Address of the new oracle
     */
    function updateOracle(address _newOracle) external onlyAdmin {
        if (_newOracle == address(0)) revert InvalidAddress();

        address oldOracle = address(oracle);
        oracle = NavOracle(_newOracle);

        emit OracleUpdated(oldOracle, _newOracle);
    }

    /**
     * @notice Set the transfer approval module
     * @param _transferApproval Address of the transfer approval module
     */
    function setTransferApproval(address _transferApproval) external onlyAdmin {
        if (_transferApproval == address(0)) revert InvalidAddress();

        address oldModule = transferApproval;
        transferApproval = _transferApproval;

        emit TransferApprovalUpdated(oldModule, _transferApproval);
    }

    /**
     * @notice Set the subscription manager
     * @param _subscriptionManager Address of the subscription manager
     */
    function setSubscriptionManager(address _subscriptionManager) external onlyAdmin {
        if (_subscriptionManager == address(0)) revert InvalidAddress();

        address oldManager = subscriptionManager;
        subscriptionManager = _subscriptionManager;

        emit SubscriptionManagerUpdated(oldManager, _subscriptionManager);
    }

    /**
     * @notice Set the underlying asset
     * @param _underlyingAsset Address of the underlying asset
     */
    function setUnderlyingAsset(address _underlyingAsset) external onlyAdmin {
        if (_underlyingAsset == address(0)) revert InvalidAddress();

        address oldAsset = underlyingAsset;
        underlyingAsset = _underlyingAsset;

        emit UnderlyingAssetUpdated(oldAsset, _underlyingAsset);
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