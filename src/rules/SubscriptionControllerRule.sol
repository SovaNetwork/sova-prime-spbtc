// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseRules} from "./BaseRules.sol";
import {ISubscriptionController} from "../controllers/ISubscriptionController.sol";

/**
 * @title SubscriptionControllerRule
 * @notice Rule that delegates validation to a subscription controller
 * @dev Implements subscription validation through the rules interface
 */
contract SubscriptionControllerRule is BaseRules {
    // Constants
    uint256 private constant RULE_BITMAP = 0x2; // Applies to deposits (0x2)
    
    // The subscription controller
    ISubscriptionController public immutable controller;
    
    // Events
    event ControllerValidation(address user, uint256 assets, bool approved, string reason);
    
    // Errors
    error InvalidController();
    
    /**
     * @notice Constructor
     * @param _controller Address of the subscription controller
     */
    constructor(address _controller) BaseRules("SubscriptionControllerRule") {
        if (_controller == address(0)) revert InvalidController();
        controller = ISubscriptionController(_controller);
    }
    
    /**
     * @notice Returns the bitmap of operations this rule applies to
     * @return Bitmap of operations (only deposits)
     */
    function appliesTo() external pure override returns (uint256) {
        return RULE_BITMAP;
    }
    
    /**
     * @notice Delegates deposit validation to the controller
     * @param token Address of the tRWA token
     * @param user Address initiating the deposit
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address token,
        address user,
        uint256 assets,
        address receiver
    ) public override returns (RuleResult memory) {
        // Delegate validation to the controller
        (bool valid, string memory reason) = controller.validateDeposit(receiver, assets);
        
        emit ControllerValidation(receiver, assets, valid, reason);
        
        return RuleResult({
            approved: valid,
            reason: reason
        });
    }
}