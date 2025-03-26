// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {tRWA} from "./tRWA.sol";

/**
 * @title NavOracle
 * @notice Oracle contract for updating underlying value per token in tRWA tokens
 * @dev This is a simplified oracle. In production, you would want more security measures
 */
contract NavOracle {
    address public admin;
    mapping(address => bool) public authorizedUpdaters;
    mapping(address => bool) public supportedTokens;

    // Events
    event UnderlyingValueUpdated(address indexed token, uint256 newUnderlyingPerToken, uint256 timestamp);
    event UpdaterStatusChanged(address indexed updater, bool isAuthorized);
    event TokenStatusChanged(address indexed token, bool isSupported);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    // Errors
    error Unauthorized();
    error UnsupportedToken();
    error InvalidUnderlyingValue();
    error InvalidAddress();

    /**
     * @notice Contract constructor
     */
    constructor() {
        admin = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }

    /**
     * @notice Modifier to restrict function calls to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Modifier to restrict function calls to authorized updaters
     */
    modifier onlyAuthorizedUpdater() {
        if (!authorizedUpdaters[msg.sender]) revert Unauthorized();
        _;
    }

    /**
     * @notice Update the underlying value per token for a supported token
     * @param _token Address of the tRWA token
     * @param _newUnderlyingPerToken New underlying value per token in USD (18 decimals)
     */
    function updateUnderlyingValue(address _token, uint256 _newUnderlyingPerToken) external onlyAuthorizedUpdater {
        if (!supportedTokens[_token]) revert UnsupportedToken();
        if (_newUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        tRWA token = tRWA(_token);
        token.updateUnderlyingValue(_newUnderlyingPerToken);

        emit UnderlyingValueUpdated(_token, _newUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Add or remove an authorized updater
     * @param _updater Address of the updater
     * @param _isAuthorized Whether the address is authorized
     */
    function setUpdaterStatus(address _updater, bool _isAuthorized) external onlyAdmin {
        if (_updater == address(0)) revert InvalidAddress();

        authorizedUpdaters[_updater] = _isAuthorized;

        emit UpdaterStatusChanged(_updater, _isAuthorized);
    }

    /**
     * @notice Add or remove a supported token
     * @param _token Address of the tRWA token
     * @param _isSupported Whether the token is supported
     */
    function setTokenStatus(address _token, bool _isSupported) external onlyAdmin {
        if (_token == address(0)) revert InvalidAddress();

        supportedTokens[_token] = _isSupported;

        emit TokenStatusChanged(_token, _isSupported);
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
}