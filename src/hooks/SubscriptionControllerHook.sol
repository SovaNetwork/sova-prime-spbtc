// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseOperationHook} from "./BaseOperationHook.sol";
import {IOperationHook, HookOutput} from "./IOperationHook.sol"; // Import HookOutput explicitly if needed
import {ISubscriptionController} from "../controllers/ISubscriptionController.sol";

/**
 * @title SubscriptionControllerHook
 * @notice Hook that delegates validation to a subscription controller
 * @dev Implements subscription validation through the operation hook interface
 */
contract SubscriptionControllerHook is BaseOperationHook {
    // Constants
    uint256 private constant APPLIES_TO_DEPOSIT = 0x2; // Bitmap for deposit operations

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
    constructor(address _controller) BaseOperationHook("SubscriptionControllerHook") {
        if (_controller == address(0)) revert InvalidController();
        controller = ISubscriptionController(_controller);
    }

    /**
     * @notice Returns the bitmap of operations this hook applies to
     * @return Bitmap of operations (only deposits for this hook)
     */
    function appliesTo() external pure override returns (uint256) {
        return APPLIES_TO_DEPOSIT;
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
    ) public override returns (HookOutput memory output) {
        // Original SubscriptionControllerRule used 'receiver' for controller.validateDeposit(receiver, assets)
        // Assuming 'receiver' is the entity whose eligibility is being checked for subscription.
        (bool valid, string memory reason) = controller.validateDeposit(receiver, assets);

        emit ControllerValidationViaHook(receiver, assets, valid, reason);

        return HookOutput({
            approved: valid,
            reason: reason
        });
    }

    // evaluateWithdraw and evaluateTransfer are not overridden here,
    // so they would revert if called unless BaseOperationHook provides default (reverting) implementations
    // or marks them as abstract and this contract is also abstract (which it isn't).
    // For now, assuming they are not used for this specific hook or BaseOperationHook handles them.
    // If IRules had them and they must be callable, they need an implementation (e.g., return approved: false).
    function onBeforeWithdraw(
        address, /*token*/
        address, /*by*/
        uint256, /*assets*/
        address, /*to*/
        address /*owner*/
    ) public /*pure*/ override returns (HookOutput memory) { // Made non-pure as Base is virtual
        return HookOutput({ approved: false, reason: "SubscriptionControllerHook does not evaluate withdrawals" });
    }

    function onBeforeTransfer(
        address, /*token*/
        address, /*from*/
        address, /*to*/
        uint256 /*amount*/
    ) public /*pure*/ override returns (HookOutput memory) { // Made non-pure as Base is virtual
        return HookOutput({ approved: false, reason: "SubscriptionControllerHook does not evaluate transfers" });
    }
}