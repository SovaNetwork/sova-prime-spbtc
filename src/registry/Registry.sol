// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LibClone} from "solady/utils/LibClone.sol";
import {IStrategy} from "../strategy/IStrategy.sol";
import {RoleManaged} from "../auth/RoleManaged.sol";
import {ItRWA} from "../token/ItRWA.sol";
import {Conduit} from "../conduit/Conduit.sol";

/**
 * @title Registry
 * @notice Central registry for strategies, rules, assets, and reporters
 * @dev Uses minimal proxy pattern for cloning templates
 */
contract Registry is RoleManaged {
    using LibClone for address;

    // Singleton contracts
    address public immutable conduit;

    // Registry mappings
    mapping(address => bool) public allowedStrategies;
    mapping(address => bool) public allowedHooks;
    mapping(address => bool) public allowedAssets;

    // Deployed contracts registry
    address[] public allStrategies;
    mapping(address => bool) public isStrategy;

    // Events
    event SetStrategy(address indexed implementation, bool allowed);
    event SetHook(address indexed implementation, bool allowed);
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
     * @param _roleManager Address of the role manager - singleton contract for managing protocol roles
     */
    constructor(address _roleManager) RoleManaged(_roleManager) {
        if (_roleManager == address(0)) revert ZeroAddress();

        // Initialize the conduit with the registry address
        conduit = address(new Conduit(address(this)));
    }

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
    function setHook(address implementation, bool allowed) external onlyRoles(roleManager.RULES_ADMIN()) {
        if (implementation == address(0)) revert ZeroAddress();
        allowedHooks[implementation] = allowed;
        emit SetHook(implementation, allowed);
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
     * @param _manager Manager address for the strategy
     * @param _initData Initialization data
     * @return strategy Address of the deployed strategy
     * @return token Address of the deployed tRWA token
     */
    function deploy(
        address _implementation,
        string memory _name,
        string memory _symbol,
        address _asset,
        uint8 _assetDecimals,
        address _manager,
        bytes memory _initData
    ) external onlyRoles(roleManager.STRATEGY_OPERATOR()) returns (address strategy, address token) {
        if (!allowedAssets[_asset]) revert UnauthorizedAsset();
        if (!allowedStrategies[_implementation]) revert UnauthorizedStrategy();

        // Clone the implementation
        strategy = _implementation.clone();

        // Initialize the strategy
        IStrategy(strategy).initialize(
            _name,
            _symbol,
            _manager,
            _asset,
            _assetDecimals,
            _initData
        );

        // Get the token address
        token = IStrategy(strategy).sToken();

        // Register strategy in the factory
        allStrategies.push(strategy);
        isStrategy[strategy] = true;

        emit Deploy(strategy, token, _asset);

        return (strategy, token);
    }

    /**
     * @notice Check if a token is a tRWA token
     * @param token Address of the token
     * @return bool True if the token is a tRWA token, false otherwise
     */
    function isToken(address token) external view returns (bool) {
        ItRWA tokenContract = ItRWA(token);
        address strategy = address(tokenContract.strategy());

        return isStrategy[strategy];
    }

    /**
     * @notice Get all tRWA tokens
     * @return tokens Array of tRWA token addresses
     */
    function allTokens() external view returns (address[] memory tokens) {
        tokens = new address[](allStrategies.length);

        for (uint256 i = 0; i < allStrategies.length; i++) {
            tokens[i] = IStrategy(allStrategies[i]).sToken();
        }
    }
}