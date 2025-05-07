// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct HookOutput {
    bool approved;
    string reason;
}

interface IOperationHook {
    function appliesTo() external pure returns (uint256); // Bitmap indicating applicable operations

    function evaluateDeposit(
        address token,
        address user,
        uint256 assets,
        address receiver
    ) external returns (HookOutput memory);

    function evaluateWithdraw(
        address token,
        address by,
        uint256 assets,
        address to,
        address owner
    ) external returns (HookOutput memory);

    function evaluateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external returns (HookOutput memory);

    // Add other evaluate methods here if they were part of the original IRules interface
    // and are expected by tRWA or other components.
}