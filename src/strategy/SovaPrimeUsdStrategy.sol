// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawReportedStrategy} from "./ManagedWithdrawRWAStrategy.sol";

/// @title SovaPrimeUsdStrategy
/// @notice USD vault strategy with managed withdrawals
contract SovaPrimeUsdStrategy is ManagedWithdrawReportedStrategy {
    /// @notice EIP-712 Type Hash Constants
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /**
     * @notice Calculate the EIP-712 domain separator with correct contract name
     * @return The domain separator
     */
    function _domainSeparator() internal view override returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("Sova Prime USD Strategy")),
                keccak256(bytes("V1")),
                block.chainid,
                address(this)
            )
        );
    }
}
