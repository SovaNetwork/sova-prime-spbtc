// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LibClone} from "solady/utils/LibClone.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IRules} from "../rules/IRules.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
/**
 * @title Registry
 * @notice Central registry for strategies, rules, assets, and reporters
 * @dev Uses minimal proxy pattern for cloning templates
 */
contract Registry is RoleManaged {
    using LibClone for address;

    // Registry mappings
    mapping(address => bool) public allowedStrategies;
    mapping(address => bool) public allowedRules;
    mapping(address => bool) public allowedAssets;

    // Deployed contracts registry
    address[] public allStrategies;

    // Events
    event SetStrategy(address indexed implementation, bool allowed);
    event SetRules(address indexed implementation, bool allowed);
    event SetAsset(address indexed asset, bool allowed);
    event Deploy(address indexed strategy, address indexed sToken, address indexed asset);

    // Errors
    error ZeroAddress();
    error UnauthorizedStrategy();
    error UnauthorizedRule();
    error UnauthorizedAsset();
    error InvalidInitialization();

    /**
     * @notice Constructor
     */
    constructor(address _roleManager) RoleManaged(_roleManager) {}

    /**
     * @notice Register a strategy implementation template
     * @param implementation Address of the strategy implementation
     * @param allowed Whether the implementation is allowed
     */
    function setStrategy(address implementation, bool allowed) external onlyRole(roleManager.STRATEGY_ADMIN()) {
        if (implementation == address(0)) revert ZeroAddress();
        allowedStrategies[implementation] = allowed;
        emit SetStrategy(implementation, allowed);
    }

    /**
     * @notice Register a rules implementation template
     * @param implementation Address of the rules implementation
     * @param allowed Whether the implementation is allowed
     */
    function setRules(address implementation, bool allowed) external onlyRole(roleManager.RULES_ADMIN()) {
        if (implementation == address(0)) revert ZeroAddress();
        allowedRules[implementation] = allowed;
        emit SetRules(implementation, allowed);
    }

    /**
     * @notice Register an asset
     * @param asset Address of the asset
     * @param allowed Whether the asset is allowed
     */
    function setAsset(address asset, bool allowed) external onlyRole(roleManager.PROTOCOL_ADMIN()) {
        if (asset == address(0)) revert ZeroAddress();
        allowedAssets[asset] = allowed;
        emit SetAsset(asset, allowed);
    }

     /**
     * @notice Deploy a new ReportedStrategy and its associated tRWA token
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _asset Asset address
     * @param _rules Rules address
     * @param _manager Manager address for the strategy
     * @param _initData Initialization data
     * @return strategy Address of the deployed strategy
     * @return token Address of the deployed tRWA token
     */
    function deploy(
        string memory _name,
        string memory _symbol,
        address _implementation,
        address _asset,
        address _rules,
        address _manager,
        bytes memory _initData
    ) external onlyRole(roleManager.STRATEGY_ADMIN()) returns (address strategy, address token) {
        if (!allowedRules[_rules]) revert UnauthorizedRule();
        if (!allowedAssets[_asset]) revert UnauthorizedAsset();
        if (!allowedStrategies[_implementation]) revert UnauthorizedStrategy();

        // Clone the implementation
        strategy = _implementation.clone();

        // Initialize the strategy
        IStrategy(strategy).initialize(_name, _symbol, _manager, _asset, _rules, _initData);

        // Register strategy in the factory
        allStrategies.push(strategy);

        // Get the token address
        token = IStrategy(strategy).sToken();

        emit Deploy(strategy, token, _asset);

        return (strategy, token);
    }

}