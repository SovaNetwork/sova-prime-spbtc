// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LibClone} from "solady/utils/LibClone.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {IOperationHook} from "../rules/IOperationHook.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {SubscriptionController} from "../controllers/SubscriptionController.sol";
import {SubscriptionControllerHook} from "../rules/SubscriptionControllerHook.sol";
/**
 * @title Registry
 * @notice Central registry for strategies, rules, assets, and reporters
 * @dev Uses minimal proxy pattern for cloning templates
 */
contract Registry is RoleManaged {
    using LibClone for address;

    // Registry mappings
    mapping(address => bool) public allowedStrategies;
    mapping(address => bool) public allowedOperationHooks;
    mapping(address => bool) public allowedAssets;

    // Deployed contracts registry
    address[] public allStrategies;

    // Controller tracking
    mapping(address => address) public strategyControllers;

    // Events
    event SetStrategy(address indexed implementation, bool allowed);
    event SetOperationHook(address indexed implementation, bool allowed);
    event SetAsset(address indexed asset, bool allowed);
    event Deploy(address indexed strategy, address indexed sToken, address indexed asset);
    event DeployWithController(address indexed strategy, address indexed sToken, address indexed controller);

    // Errors
    error ZeroAddress();
    error UnauthorizedStrategy();
    error UnauthorizedHook();
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
    function setStrategy(address implementation, bool allowed) external onlyRoles(roleManager.STRATEGY_ADMIN()) {
        if (implementation == address(0)) revert ZeroAddress();
        allowedStrategies[implementation] = allowed;
        emit SetStrategy(implementation, allowed);
    }

    /**
     * @notice Register an operation hook implementation template
     * @param implementation Address of the hook implementation
     * @param allowed Whether the implementation is allowed
     */
    function setOperationHook(address implementation, bool allowed) external onlyRoles(roleManager.RULES_ADMIN()) {
        if (implementation == address(0)) revert ZeroAddress();
        allowedOperationHooks[implementation] = allowed;
        emit SetOperationHook(implementation, allowed);
    }

    /**
     * @notice Register an asset
     * @param asset Address of the asset
     * @param allowed Whether the asset is allowed
     */
    function setAsset(address asset, bool allowed) external onlyRoles(roleManager.PROTOCOL_ADMIN()) {
        if (asset == address(0)) revert ZeroAddress();
        allowedAssets[asset] = allowed;
        emit SetAsset(asset, allowed);
    }

     /**
     * @notice Deploy a new ReportedStrategy and its associated tRWA token
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _asset Asset address
     * @param _assetDecimals Asset decimals
     * @param _operationHook Operation hook address
     * @param _operationHookAddresses Array of operation hook addresses
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
        uint8 _assetDecimals,
        address[] memory _operationHookAddresses,
        address _manager,
        bytes memory _initData
    ) external onlyRoles(roleManager.STRATEGY_OPERATOR()) returns (address strategy, address token) {
        return deployBase(_name, _symbol, _implementation, _asset, _assetDecimals, _operationHookAddresses, _manager, _initData);
    }

    /**
     * @notice Deploy a strategy with a subscription controller
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _implementation Strategy implementation address
     * @param _asset Asset address
     * @param _assetDecimals Asset decimals
     * @param _manager Manager address for the strategy
     * @param _managerAddresses Additional manager addresses for the controller
     * @param _additionalHookAddresses Array of additional hook addresses to include
     * @param _initData Initialization data
     * @param initialCapacity Initial subscription capacity
     * @return strategy Address of the deployed strategy
     * @return token Address of the deployed tRWA token
     * @return controller Address of the deployed controller
     */
    function deployWithController(
        string memory _name,
        string memory _symbol,
        address _implementation,
        address _asset,
        uint8 _assetDecimals,
        address _manager,
        address[] memory _managerAddresses,
        address[] calldata _additionalHookAddresses,
        bytes memory _initData,
        uint256 initialCapacity
    ) external onlyRoles(roleManager.STRATEGY_OPERATOR()) returns (address strategy, address token, address controller) {
        // Deploy controller first (no longer needs token address at construction)
        controller = address(new SubscriptionController(
            _manager,
            _managerAddresses
        ));

        // Deploy the hook for the controller
        address controllerHook = address(new SubscriptionControllerHook(controller));

        // Construct the full list of operation hooks
        address[] memory allHookAddresses = new address[](_additionalHookAddresses.length + 1);
        allHookAddresses[0] = controllerHook;
        for (uint i = 0; i < _additionalHookAddresses.length; i++) {
            allHookAddresses[i+1] = _additionalHookAddresses[i];
        }

        // Deploy strategy and token using the combined list of hooks
        (strategy, token) = deployBase(_name, _symbol, _implementation, _asset, _assetDecimals, allHookAddresses, _manager, _initData);

        // Register controller address with the strategy (for informational purposes in Registry)
        strategyControllers[strategy] = controller;

        // Note: The strategy's initialize function or a subsequent setup call by the manager
        // is responsible for calling ITRWA(token).setController(controllerAddress)
        // to enable the callback mechanism in SubscriptionController.

        emit DeployWithController(strategy, token, controller);

        return (strategy, token, controller);
    }

    /**
     * @notice Base deployment function for strategies
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _implementation Strategy implementation address
     * @param _asset Asset address
     * @param _assetDecimals Asset decimals
     * @param _operationHookAddresses Array of operation hook addresses
     * @param _manager Manager address
     * @param _initData Initialization data
     * @return strategy Deployed strategy address
     * @return token Deployed token address
     */
    function deployBase(
        string memory _name,
        string memory _symbol,
        address _implementation,
        address _asset,
        uint8 _assetDecimals,
        address[] memory _operationHookAddresses,
        address _manager,
        bytes memory _initData
    ) internal returns (address strategy, address token) {
        // Validate all provided hook addresses
        if (_operationHookAddresses.length == 0) revert UnauthorizedHook();
        for (uint i = 0; i < _operationHookAddresses.length; i++) {
            if (!allowedOperationHooks[_operationHookAddresses[i]]) revert UnauthorizedHook();
        }

        if (!allowedAssets[_asset]) revert UnauthorizedAsset();
        if (!allowedStrategies[_implementation]) revert UnauthorizedStrategy();

        // Clone the implementation
        strategy = _implementation.clone();

        // Initialize the strategy
        IStrategy(strategy).initialize(_name, _symbol, _manager, _asset, _assetDecimals, _operationHookAddresses, _initData);

        // Register strategy in the factory
        allStrategies.push(strategy);

        // Get the token address
        token = IStrategy(strategy).sToken();

        emit Deploy(strategy, token, _asset);

        return (strategy, token);
    }

}