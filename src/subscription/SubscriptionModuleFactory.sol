// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ISubscriptionModule} from "../interfaces/ISubscriptionModule.sol";
import {AutomaticSubscriptionModule} from "./AutomaticSubscriptionModule.sol";
import {CappedSubscriptionModule} from "./CappedSubscriptionModule.sol";
import {ApprovalSubscriptionModule} from "./ApprovalSubscriptionModule.sol";

/**
 * @title SubscriptionModuleFactory
 * @notice Factory contract for deploying different types of subscription modules
 */
contract SubscriptionModuleFactory {
    address public admin;

    // Module tracking
    mapping(address => bool) public isRegisteredModule;
    address[] public allModules;

    // Module type enum
    enum ModuleType {
        AUTOMATIC,
        CAPPED,
        APPROVAL
    }

    // Events
    event ModuleDeployed(address indexed module, ModuleType moduleType, address indexed token);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();

    /**
     * @notice Constructor for the SubscriptionModuleFactory
     */
    constructor() {
        admin = msg.sender;
    }

    /**
     * @notice Modifier to restrict function calls to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Deploy an automatic subscription module
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     * @return moduleAddress Address of the deployed module
     */
    function deployAutomaticModule(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        bool _isOpen
    ) external onlyAdmin returns (address moduleAddress) {
        if (_token == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_minSubscriptionAmount == 0) revert InvalidAmount();
        if (_tokenPriceInUSD == 0) revert InvalidAmount();

        AutomaticSubscriptionModule module = new AutomaticSubscriptionModule(
            _token,
            _treasury,
            _minSubscriptionAmount,
            _tokenPriceInUSD,
            _isOpen
        );

        moduleAddress = address(module);

        // Register module
        isRegisteredModule[moduleAddress] = true;
        allModules.push(moduleAddress);

        emit ModuleDeployed(moduleAddress, ModuleType.AUTOMATIC, _token);

        return moduleAddress;
    }

    /**
     * @notice Deploy a capped subscription module
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _maxCap Maximum total investment cap in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     * @return moduleAddress Address of the deployed module
     */
    function deployCappedModule(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        uint256 _maxCap,
        bool _isOpen
    ) external onlyAdmin returns (address moduleAddress) {
        if (_token == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_minSubscriptionAmount == 0) revert InvalidAmount();
        if (_tokenPriceInUSD == 0) revert InvalidAmount();
        if (_maxCap == 0) revert InvalidAmount();

        CappedSubscriptionModule module = new CappedSubscriptionModule(
            _token,
            _treasury,
            _minSubscriptionAmount,
            _tokenPriceInUSD,
            _maxCap,
            _isOpen
        );

        moduleAddress = address(module);

        // Register module
        isRegisteredModule[moduleAddress] = true;
        allModules.push(moduleAddress);

        emit ModuleDeployed(moduleAddress, ModuleType.CAPPED, _token);

        return moduleAddress;
    }

    /**
     * @notice Deploy an approval-based subscription module
     * @param _token The tRWA token this subscription module is for
     * @param _treasury The treasury address where funds will be sent
     * @param _minSubscriptionAmount Minimum subscription amount in USD (18 decimals)
     * @param _tokenPriceInUSD Initial token price in USD (18 decimals)
     * @param _isOpen Whether subscriptions are initially open
     * @return moduleAddress Address of the deployed module
     */
    function deployApprovalModule(
        address _token,
        address _treasury,
        uint256 _minSubscriptionAmount,
        uint256 _tokenPriceInUSD,
        bool _isOpen
    ) external onlyAdmin returns (address moduleAddress) {
        if (_token == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_minSubscriptionAmount == 0) revert InvalidAmount();
        if (_tokenPriceInUSD == 0) revert InvalidAmount();

        ApprovalSubscriptionModule module = new ApprovalSubscriptionModule(
            _token,
            _treasury,
            _minSubscriptionAmount,
            _tokenPriceInUSD,
            _isOpen
        );

        moduleAddress = address(module);

        // Register module
        isRegisteredModule[moduleAddress] = true;
        allModules.push(moduleAddress);

        emit ModuleDeployed(moduleAddress, ModuleType.APPROVAL, _token);

        return moduleAddress;
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
     * @notice Get all registered modules
     * @return modules Array of registered module addresses
     */
    function getAllModules() external view returns (address[] memory) {
        return allModules;
    }

    /**
     * @notice Get the number of registered modules
     * @return count Number of registered modules
     */
    function getModuleCount() external view returns (uint256) {
        return allModules.length;
    }
}