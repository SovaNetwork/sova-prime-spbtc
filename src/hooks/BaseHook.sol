// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IHook} from "./IHook.sol";

abstract contract BaseHook is IHook {
    string public name;

    /**
     * @notice Constructor
     * @param _name Human readable name of the hook
     */
    constructor(string memory _name) {
        name = _name;
    }

    /**
     * @notice Returns the unique identifier for this hook
     * @return Hook identifier
     */
    function hookId() external view returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    /**
     * @notice Returns the human readable name of this hook
     * @return Hook name
     */
    function hookName() external view returns (string memory) {
        return name;
    }

    /**
     * @notice Called before a deposit operation
     * @return HookOutput Result of the hook evaluation
     */
    function onBeforeDeposit(
        address, /*token*/
        address, /*user*/
        uint256, /*assets*/
        address  /*receiver*/
    ) public virtual override returns (IHook.HookOutput memory) {
        return IHook.HookOutput({approved: true, reason: ""});
    }

    /**
     * @notice Called before a withdraw operation
     * @return HookOutput Result of the hook evaluation
     */
    function onBeforeWithdraw(
        address, /*token*/
        address, /*by*/
        uint256, /*assets*/
        address, /*to*/
        address  /*owner*/
    ) public virtual override returns (IHook.HookOutput memory) {
        return IHook.HookOutput({approved: true, reason: ""});
    }

    /**
     * @notice Called before a transfer operation
     * @return HookOutput Result of the hook evaluation
     */
    function onBeforeTransfer(
        address, /*token*/
        address, /*from*/
        address, /*to*/
        uint256  /*amount*/
    ) public virtual override returns (IHook.HookOutput memory) {
        return IHook.HookOutput({approved: true, reason: ""});
    }
}
