// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {Ownable} from "solady/auth/Ownable.sol";

import {tRWA} from "./tRWA.sol";
import {ItRWA} from "./ItRWA.sol";

/**
 * @title tRWAFactory
 * @notice Factory contract for deploying new tRWA tokens
 */
contract tRWAFactory is Ownable {
    address public admin;

    // Registries for approved contracts
    mapping(address => bool) public allowedRules;
    mapping(address => bool) public allowedAssets;

    address[] public allTokens;

    // Events
    event Deployed(address indexed token, string name, string symbol);
    event SetRule(address indexed rule, bool approved);
    event SetAsset(address indexed asset, bool approved);

    // Errors
    error InvalidAddress();
    error UnapprovedRule();
    error UnapprovedAsset();

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
     * @param _asset Asset address
     * @param _strategy Strategy address
     * @param _rules Rules address
     * @return token Address of the deployed token
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        address _asset,
        address _strategy,
        address _rules
    ) external onlyOwner returns (address) {
        // TODO: Have strategy deploy token?

        if (!allowedRules[_rules]) revert UnapprovedRule();
        if (!allowedAssets[_asset]) revert UnapprovedAsset();

        // Deploy new tRWA token
        tRWA newToken = new tRWA(
            _name,
            _symbol,
            _asset,
            _strategy,
            _rules
        );

        // Register token in the factory
        address tokenAddr = address(newToken);
        allTokens.push(tokenAddr);

        emit Deployed(tokenAddr, _name, _symbol);

        return tokenAddr;
    }

    /**
     * @notice Approve a rule
     * @param _rule Rule to approve
     */
    function setRule(address _rule, bool _approved) external onlyOwner {
        allowedRules[_rule] = _approved;
        emit SetRule(_rule, _approved);
    }

    /**
     * @notice Approve an asset
     * @param _asset Asset to approve
     */
    function setAsset(address _asset, bool _approved) external onlyOwner {
        allowedAssets[_asset] = _approved;
        emit SetAsset(_asset, _approved);
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