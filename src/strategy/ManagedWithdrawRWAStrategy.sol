// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ManagedWithdrawRWA} from "../token/ManagedWithdrawRWA.sol";
import {ReportedStrategy} from "./ReportedStrategy.sol";

/**
 * @title ManagedWithdrawReportedStrategy
 * @notice Extension of ReportedStrategy that deploys and configures ManagedWithdrawRWA tokens
 */
contract ManagedWithdrawReportedStrategy is ReportedStrategy {

    // Custom errors
    error WithdrawalRequestExpired();
    error WithdrawRequestLapsedRound();
    error WithdrawNonceReuse();
    error WithdrawInvalidSignature();
    error InvalidArrayLengths();
    struct WithdrawalRequest {
        uint256 shares;
        address owner;
        uint96 nonce;
        address to;
        uint96 expirationTime;
        uint64 maxRound;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // EIP-712 Type Hash Constants
    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 private constant WITHDRAWAL_REQUEST_TYPEHASH = keccak256(
        "WithdrawalRequest(address owner,address to,uint256 shares,uint256 nonce,uint96 expirationTime,uint96 maxRound)"
    );

    // Domain separator for signatures
    bytes32 private DOMAIN_SEPARATOR;

    // Tracking of batch withdrawals
    uint64 public currentRound;

    // Tracking of used nonces
    mapping(address => mapping(uint96 => bool)) public usedNonces;

    /**
     * @notice Initialize the strategy with ManagedWithdrawRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param roleManager_ Address of the role manager
     * @param manager_ Address of the manager
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     * @param initData Additional initialization data (unused)
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address asset_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public override {
        super.initialize(name_, symbol_, roleManager_, manager_, asset_, assetDecimals_, initData);

        // Initialize EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("ManagedWithdrawReportedStrategy")),
                keccak256(bytes("V1")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Deploy a new ManagedWithdrawRWA token
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param asset_ Address of the underlying asset
     * @param assetDecimals_ Decimals of the asset
     */
    function _deployToken(
        string calldata name_,
        string calldata symbol_,
        address asset_,
        uint8 assetDecimals_
    ) internal virtual override returns (address) {
        ManagedWithdrawRWA newToken = new ManagedWithdrawRWA(
            name_,
            symbol_,
            asset_,
            assetDecimals_,
            address(this)
        );

        return address(newToken);
    }

    /**
     * @notice Process a user-requested withdrawal
     * @param request The withdrawal request
     * @param userSig The signature of the request
     * @return assets The amount of assets received
     */
    function redeem(
        WithdrawalRequest calldata request,
        Signature calldata userSig
    ) external onlyManager returns (uint256 assets) {
        _validateRedeem(request);

        // Verify signature
        _verifySignature(request, userSig);

        // Mark nonce as used
        usedNonces[request.owner][request.nonce] = true;

        // Increment round
        currentRound++;

        assets = ManagedWithdrawRWA(sToken).redeem(request.shares, request.to, request.owner);
    }

    /**
     * @notice Process a batch of user-requested withdrawals
     * @param requests The withdrawal requests
     * @param signatures The signatures of the requests
     * @return assets The amount of assets received
     */
    function batchRedeem(
        WithdrawalRequest[] calldata requests,
        Signature[] calldata signatures
    ) external onlyManager returns (uint256[] memory assets) {
        if (requests.length != signatures.length) revert InvalidArrayLengths();

        uint256[] memory shares = new uint256[](requests.length);
        address[] memory recipients = new address[](requests.length);
        address[] memory owners = new address[](requests.length);

        for (uint256 i = 0; i < requests.length; i++) {
            _validateRedeem(requests[i]);
            _verifySignature(requests[i], signatures[i]);
            usedNonces[requests[i].owner][requests[i].nonce] = true;

            shares[i] = requests[i].shares;
            recipients[i] = requests[i].to;
            owners[i] = requests[i].owner;
        }

        // Increment round
        currentRound++;

        assets = ManagedWithdrawRWA(sToken).batchRedeemShares(shares, recipients, owners);
    }

    function _validateRedeem(WithdrawalRequest calldata request) internal view {
        if (request.expirationTime < block.timestamp) revert WithdrawalRequestExpired();
        if (request.maxRound < currentRound) revert WithdrawRequestLapsedRound();
        if (usedNonces[request.owner][request.nonce]) revert WithdrawNonceReuse();
    }

    /**
     * @notice Verify a signature using EIP-712
     * @param request The withdrawal request
     * @param signature The signature
     */
    function _verifySignature(WithdrawalRequest calldata request, Signature calldata signature) internal view {
        // Verify signature
        bytes32 structHash = keccak256(
            abi.encode(
                WITHDRAWAL_REQUEST_TYPEHASH,
                request.owner,
                request.to,
                request.shares,
                request.nonce,
                request.expirationTime,
                request.maxRound
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        // Recover signer address from signature
        address signer = ecrecover(
            digest,
            signature.v,
            signature.r,
            signature.s
        );

        // Verify the signer is the owner of the shares
        if (signer != request.owner) revert WithdrawInvalidSignature();
    }
}