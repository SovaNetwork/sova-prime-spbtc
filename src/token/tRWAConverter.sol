// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {tRWA} from "./tRWA.sol";
import {tRWARebase} from "./tRWARebase.sol";

/**
 * @title tRWAConverter
 * @notice Allows conversion between share-based tRWA and rebasing tRWARebase tokens
 * @dev Maintains an internal accounting of shares to track ownership
 */
contract tRWAConverter {
    // References to token contracts
    tRWA public shareToken;
    tRWARebase public rebaseToken;

    // Admin address
    address public admin;

    // Events
    event ConvertedToRebase(address indexed user, uint256 shareAmount, uint256 rebaseAmount);
    event ConvertedToShares(address indexed user, uint256 rebaseAmount, uint256 shareAmount);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    // Errors
    error Unauthorized();
    error InvalidAmount();
    error InsufficientBalance();
    error InvalidTokenPair();
    error InvalidAddress();

    /**
     * @notice Contract constructor
     * @param _shareToken The share-based tRWA token
     * @param _rebaseToken The rebasing tRWARebase token
     */
    constructor(address _shareToken, address _rebaseToken) {
        if (_shareToken == address(0) || _rebaseToken == address(0)) revert InvalidAddress();

        shareToken = tRWA(_shareToken);
        rebaseToken = tRWARebase(_rebaseToken);
        admin = msg.sender;

        // Validate token pair by checking they have the same underlying asset
        // This could be done by checking name, symbol or other uniquely identifying parameters
        if (keccak256(abi.encodePacked(shareToken.symbol())) !=
            keccak256(abi.encodePacked(rebaseToken.symbol()))) {
            revert InvalidTokenPair();
        }
    }

    /**
     * @notice Modifier to restrict function calls to authorized addresses
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
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
     * @notice Convert share-based tokens to rebasing tokens
     * @param _shareAmount Amount of share tokens to convert
     * @return rebaseAmount The amount of rebasing tokens received
     */
    function convertToRebase(uint256 _shareAmount) external returns (uint256 rebaseAmount) {
        if (_shareAmount == 0) revert InvalidAmount();
        if (shareToken.balanceOf(msg.sender) < _shareAmount) revert InsufficientBalance();

        // Calculate USD value of the shares at current rate
        uint256 usdValue = shareToken.getUsdValue(_shareAmount);

        // Calculate how many rebasing tokens to mint based on current value
        rebaseAmount = calculateRebaseAmount(usdValue);

        // Transfer share tokens from user to this contract
        bool success = shareToken.transferFrom(msg.sender, address(this), _shareAmount);
        if (!success) revert InsufficientBalance();

        // Mint rebasing tokens to the user
        rebaseToken.mint(msg.sender, rebaseAmount);

        emit ConvertedToRebase(msg.sender, _shareAmount, rebaseAmount);
        return rebaseAmount;
    }

    /**
     * @notice Convert rebasing tokens to share-based tokens
     * @param _rebaseAmount Amount of rebasing tokens to convert
     * @return shareAmount The amount of share tokens received
     */
    function convertToShares(uint256 _rebaseAmount) external returns (uint256 shareAmount) {
        if (_rebaseAmount == 0) revert InvalidAmount();
        if (rebaseToken.balanceOf(msg.sender) < _rebaseAmount) revert InsufficientBalance();

        // Calculate USD value of the rebasing tokens at current rate
        uint256 usdValue = rebaseToken.getUsdValue(_rebaseAmount);

        // Calculate how many share tokens to mint based on current value
        shareAmount = calculateShareAmount(usdValue);

        // Burn rebasing tokens from the user
        rebaseToken.burn(msg.sender, _rebaseAmount);

        // Transfer share tokens from this contract to the user
        bool success = shareToken.transfer(msg.sender, shareAmount);
        if (!success) revert InsufficientBalance();

        emit ConvertedToShares(msg.sender, _rebaseAmount, shareAmount);
        return shareAmount;
    }

    /**
     * @notice Calculate the amount of share tokens for a given USD value
     * @param _usdValue USD value (18 decimals)
     * @return shareAmount Amount of share tokens
     */
    function calculateShareAmount(uint256 _usdValue) public view returns (uint256 shareAmount) {
        uint256 underlyingPerToken = shareToken.underlyingPerToken();
        if (underlyingPerToken == 0) return _usdValue; // 1:1 if no price set yet
        return (_usdValue * 1e18) / underlyingPerToken;
    }

    /**
     * @notice Calculate the amount of rebasing tokens for a given USD value
     * @param _usdValue USD value (18 decimals)
     * @return rebaseAmount Amount of rebasing tokens
     */
    function calculateRebaseAmount(uint256 _usdValue) public view returns (uint256 rebaseAmount) {
        uint256 underlyingValue = rebaseToken.getUnderlyingValue();
        uint256 totalSupply = rebaseToken.totalSupply();

        if (underlyingValue == 0 || totalSupply == 0) return _usdValue; // 1:1 if no price set yet
        return (_usdValue * totalSupply) / underlyingValue;
    }

    /**
     * @notice Withdraw share tokens in case of emergency (admin only)
     * @param _amount Amount of share tokens to withdraw
     */
    function withdrawShareTokens(uint256 _amount) external onlyAdmin {
        uint256 balance = shareToken.balanceOf(address(this));
        if (_amount > balance) revert InsufficientBalance();

        shareToken.transfer(admin, _amount);
    }
}