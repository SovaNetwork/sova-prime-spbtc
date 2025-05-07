// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IOperationHook} from "./IOperationHook.sol";

abstract contract BaseOperationHook is IOperationHook {
    string public name;

    constructor(string memory _name) {
        name = _name;
    }

    // Concrete hooks will override appliesTo and evaluation methods.
    // Example: function appliesTo() public pure virtual override returns (uint256);
}