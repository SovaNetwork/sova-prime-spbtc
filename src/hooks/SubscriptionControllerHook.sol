// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseHook} from "./BaseHook.sol";
import {IHook} from "./IHook.sol"; // Import HookOutput explicitly if needed
import {ISubscriptionController} from "../controllers/ISubscriptionController.sol";

/**
 * @title SubscriptionControllerHook
 * @notice Hook that delegates validation to a subscription controller
 * @dev Implements subscription validation through the operation hook interface
 */
contract SubscriptionControllerHook is BaseHook {
     // The subscription controller
    ISubscriptionController public immutable controller;

    // Events
    event ControllerValidationViaHook(address user, uint256 assets, bool approved, string reason);

    // Errors
    error InvalidController();

    /**
     * @notice Constructor
     * @param _controller Address of the subscription controller
     */
    constructor(address _controller) BaseHook("SubscriptionControllerHook") {
        if (_controller == address(0)) revert InvalidController();
        controller = ISubscriptionController(_controller);
    }

    /**
     * @notice Delegates deposit validation to the controller
     * @param token Address of the tRWA token (passed by tRWA, may not be used by controller directly)
     * @param user Address initiating the deposit (passed as 'user' to controller.validateDeposit)
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares (passed as 'user' to controller.validateDeposit based on previous SCR logic)
     * @return output The hook evaluation output (approved, reason)
     */
    function onBeforeDeposit(
        address token,
        address user, // This is msg.sender in tRWA's _deposit
        uint256 assets,
        address receiver // This is the 'to' in tRWA's _deposit
    ) public override returns (IHook.HookOutput memory output) {
        // Original SubscriptionControllerRule used 'receiver' for controller.validateDeposit(receiver, assets)
        // Assuming 'receiver' is the entity whose eligibility is being checked for subscription.
        (bool valid, string memory reason) = controller.validateDeposit(receiver, assets);

        emit ControllerValidationViaHook(receiver, assets, valid, reason);

        return IHook.HookOutput({
            approved: valid,
            reason: reason
        });
    }

    // evaluateWithdraw and evaluateTransfer are not overridden here,
    // so they would revert if called unless BaseHook provides default (reverting) implementations
    // or marks them as abstract and this contract is also abstract (which it isn't).
    // For now, assuming they are not used for this specific hook or BaseHook handles them.
    // If IRules had them and they must be callable, they need an implementation (e.g., return approved: false).
    function onBeforeWithdraw(
        address, /*token*/
        address, /*by*/
        uint256, /*assets*/
        address, /*to*/
        address /*owner*/
    ) public pure override returns (IHook.HookOutput memory) { // Made non-pure as Base is virtual
        return IHook.HookOutput({ approved: false, reason: "SubscriptionControllerHook does not evaluate withdrawals" });
    }

    function onBeforeTransfer(
        address, /*token*/
        address, /*from*/
        address, /*to*/
        uint256 /*amount*/
    ) public pure override returns (IHook.HookOutput memory) { // Made non-pure as Base is virtual
        return IHook.HookOutput({ approved: false, reason: "SubscriptionControllerHook does not evaluate transfers" });
    }
}