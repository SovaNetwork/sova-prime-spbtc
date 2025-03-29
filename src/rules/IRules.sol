// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IRules
 * @notice Interface for rule implementation in the tRWA rule system
 * @dev All rules must implement this interface to be registered with the rule engine
 */
interface IRules {
    /**
     * @notice Rule evaluation result struct
     * @param approved Whether the action is approved by this rule
     * @param reason Reason for approval/rejection (for logging or error messages)
     */
    struct RuleResult {
        bool approved;
        string reason;
    }

    /**
     * @notice Returns the unique identifier for this rule
     * @return Rule identifier
     */
    function ruleId() external view returns (bytes32);

    /**
     * @notice Returns the human readable name of this rule
     * @return Rule name
     */
    function ruleName() external view returns (string memory);

    /**
     * @notice Evaluates a transfer according to this rule
     * @param token Address of the tRWA token
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param amount Amount of tokens being transferred
     * @return result Rule evaluation result
     */
    function evaluateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external view returns (RuleResult memory result);

    /**
     * @notice Evaluates a deposit according to this rule
     * @param token Address of the tRWA token
     * @param user Address initiating the deposit
     * @param assets Amount of assets being deposited
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateDeposit(
        address token,
        address user,
        uint256 assets,
        address receiver
    ) external view returns (RuleResult memory result);

    /**
     * @notice Evaluates a mint according to this rule
     * @param token Address of the tRWA token
     * @param user Address initiating the mint
     * @param shares Amount of shares being minted
     * @param receiver Address receiving the shares
     * @return result Rule evaluation result
     */
    function evaluateMint(
        address token,
        address user,
        uint256 shares,
        address receiver
    ) external view returns (RuleResult memory result);

    /**
     * @notice Evaluates a withdraw according to this rule
     * @param token Address of the tRWA token
     * @param user Address initiating the withdrawal
     * @param assets Amount of assets being withdrawn
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateWithdraw(
        address token,
        address user,
        uint256 assets,
        address receiver,
        address owner
    ) external view returns (RuleResult memory result);

    /**
     * @notice Evaluates a redeem according to this rule
     * @param token Address of the tRWA token
     * @param user Address initiating the redemption
     * @param shares Amount of shares being redeemed
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return result Rule evaluation result
     */
    function evaluateRedeem(
        address token,
        address user,
        uint256 shares,
        address receiver,
        address owner
    ) external view returns (RuleResult memory result);
}