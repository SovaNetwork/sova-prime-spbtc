// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";
import {NavOracle} from "./NavOracle.sol";

/**
 * @title tRWAFactory
 * @notice Factory contract for deploying new tRWA tokens
 */
contract tRWAFactory {
    address public admin;
    NavOracle public oracle;
    address public complianceModule;
    mapping(address => bool) public isRegisteredToken;
    address[] public allTokens;

    // Events
    event TokenDeployed(address indexed token, string name, string symbol, uint256 initialUnderlyingPerToken);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event ComplianceModuleUpdated(address indexed oldModule, address indexed newModule);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidUnderlyingValue();

    /**
     * @notice Contract constructor
     * @param _oracle Address of the oracle
     */
    constructor(address _oracle) {
        if (_oracle == address(0)) revert InvalidAddress();

        admin = msg.sender;
        oracle = NavOracle(_oracle);
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

        // Deploy new tRWA token
        tRWA newToken = new tRWA(
            _name,
            _symbol,
            address(oracle),
            _initialUnderlyingPerToken
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
     * @notice Deploy a new tRWA token with compliance
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialUnderlyingPerToken Initial underlying value per token in USD (18 decimals)
     * @param _enableCompliance Whether to enable compliance for this token
     * @return tokenAddress Address of the deployed token
     */
    function deployTokenWithCompliance(
        string memory _name,
        string memory _symbol,
        uint256 _initialUnderlyingPerToken,
        bool _enableCompliance
    ) external onlyAdmin returns (address tokenAddress) {
        if (_initialUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        // Deploy new tRWA token
        tRWA newToken = new tRWA(
            _name,
            _symbol,
            address(oracle),
            _initialUnderlyingPerToken
        );

        // Register token in the factory
        address tokenAddr = address(newToken);
        isRegisteredToken[tokenAddr] = true;
        allTokens.push(tokenAddr);

        // Register token in the oracle
        oracle.setTokenStatus(tokenAddr, true);

        // Set compliance module if available and enabled
        if (complianceModule != address(0) && _enableCompliance) {
            newToken.setComplianceModule(complianceModule);
            newToken.toggleCompliance(true);

            // Try to register token in compliance module using a safe call
            (bool success, ) = complianceModule.call(
                abi.encodeWithSignature("registerToken(address)", tokenAddr)
            );
            // Don't revert if this fails, it's not critical
        }

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
     * @notice Set the compliance module
     * @param _complianceModule Address of the compliance module
     */
    function setComplianceModule(address _complianceModule) external onlyAdmin {
        if (_complianceModule == address(0)) revert InvalidAddress();

        address oldModule = complianceModule;
        complianceModule = _complianceModule;

        emit ComplianceModuleUpdated(oldModule, _complianceModule);
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