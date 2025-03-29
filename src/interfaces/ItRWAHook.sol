// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title ItRWAHook
 * @notice Interface for hooks that can be registered with tRWA
 * @dev Hooks are called before and after each operation in tRWA
 */
interface ItRWAHook {
    // Pre-operation hooks
    function beforeDeposit(address user, uint256 assets, address receiver) external returns (bool);
    function beforeMint(address user, uint256 shares, address receiver) external returns (bool);
    function beforeWithdraw(address user, uint256 assets, address receiver, address owner) external returns (bool);
    function beforeRedeem(address user, uint256 shares, address receiver, address owner) external returns (bool);
    function beforeTransfer(address from, address to, uint256 value) external returns (bool);

    // Post-operation hooks
    function afterDeposit(address user, uint256 assets, address receiver, uint256 shares) external;
    function afterMint(address user, uint256 shares, address receiver, uint256 assets) external;
    function afterWithdraw(address user, uint256 assets, address receiver, address owner, uint256 shares) external;
    function afterRedeem(address user, uint256 shares, address receiver, address owner, uint256 assets) external;
    function afterTransfer(address from, address to, uint256 value) external;
}