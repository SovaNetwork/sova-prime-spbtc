// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";
import {IWithdrawalManager} from "./IWithdrawalManager.sol";
import {tRWA} from "../token/tRWA.sol";
import {IStrategy} from "../strategy/IStrategy.sol";

/**
 * @title WithdrawalManager
 * @notice Manages withdrawal requests and approvals for tRWA tokens
 * @dev Implements queued withdrawals with merkle-based approval
 */
contract WithdrawalManager is IWithdrawalManager, OwnableRoles {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Roles
    uint256 public constant WITHDRAWAL_ADMIN_ROLE = 1 << 0;
    uint256 public constant WITHDRAWAL_PROCESSOR_ROLE = 1 << 1;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    // Core storage
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    mapping(uint256 => WithdrawalPeriod) public withdrawalPeriods;
    mapping(address => uint256[]) public userWithdrawalRequests;

    // Counters
    uint256 private _nextRequestId = 1;
    uint256 private _nextPeriodId = 1;
    uint256 private _currentPeriodId = 0;

    // Contract references
    address public immutable token;
    address public immutable asset;
    address public immutable strategy;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param _token tRWA token address
     * @param _admin Administrator address
     */
    constructor(address _token, address _admin) {
        if (_token == address(0) || _admin == address(0)) revert InvalidAddress();

        token = _token;
        strategy = tRWA(_token).strategy();
        asset = tRWA(_token).asset();

        _initializeOwner(_admin);
        _grantRoles(_admin, WITHDRAWAL_ADMIN_ROLE | WITHDRAWAL_PROCESSOR_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Request a withdrawal
     * @param user The user requesting the withdrawal
     * @param assets The amount of assets to withdraw
     * @param shares The amount of shares to burn (can be 0 to calculate from assets)
     * @return requestId The ID of the created withdrawal request
     */
    function requestWithdrawal(address user, uint256 assets, uint256 shares) external returns (uint256 requestId) {
        if (user == address(0)) revert InvalidAddress();
        if (assets == 0) revert InvalidAmount();

        // If shares not specified, calculate from assets
        if (shares == 0) {
            // Use the ERC4626 previewWithdraw to get the number of shares needed
            shares = tRWA(token).previewWithdraw(assets);
        }

        // Create the withdrawal request
        requestId = _nextRequestId++;

        withdrawalRequests[requestId] = WithdrawalRequest({
            id: requestId,
            user: user,
            assets: assets,
            shares: shares,
            requestTime: block.timestamp,
            approved: false,
            executed: false
        });

        // Add to user's withdrawal requests
        userWithdrawalRequests[user].push(requestId);

        emit WithdrawalRequested(requestId, user, assets, shares);
        return requestId;
    }

    /**
     * @notice Execute an approved withdrawal
     * @param requestId The ID of the withdrawal request
     * @param merkleProof The merkle proof validating the approval
     * @return success Whether the withdrawal was successful
     */
    function executeWithdrawal(uint256 requestId, bytes32[] calldata merkleProof) external returns (bool success) {
        WithdrawalRequest storage request = withdrawalRequests[requestId];

        // Validate request
        if (request.id == 0) revert InvalidWithdrawalRequest();
        if (request.executed) revert WithdrawalAlreadyExecuted();

        // Get current period
        WithdrawalPeriod storage period = withdrawalPeriods[_currentPeriodId];
        if (!period.active) revert WithdrawalPeriodInactive();

        // Verify that withdrawal period hasn't expired
        if (block.timestamp > period.endTime) {
            closeWithdrawalPeriod();
            revert WithdrawalPeriodInactive();
        }

        // Verify the merkle proof
        if (!isValidWithdrawal(requestId, merkleProof)) revert InvalidMerkleProof();

        // Check if strategy has enough funds
        if (period.withdrawnAssets + request.assets > period.totalAssets) {
            revert InsufficientFunds();
        }

        // Mark as executed
        request.executed = true;

        // Update period stats
        period.withdrawnAssets += request.assets;

        // Check if all funds withdrawn
        if (period.withdrawnAssets >= period.totalAssets) {
            closeWithdrawalPeriod();
        }

        // Burn shares from user
        tRWA(token).burn(request.user, request.shares);

        // Transfer assets from strategy to user
        IStrategy(strategy).transferAssets(request.user, request.assets);

        emit WithdrawalExecuted(requestId, request.user, request.assets);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Open a new withdrawal period
     * @param duration The duration of the withdrawal period in seconds
     * @param merkleRoot The merkle root of approved withdrawals
     * @param totalAssets The total assets allocated for this period
     * @return periodId The ID of the created withdrawal period
     */
    function openWithdrawalPeriod(
        uint256 duration, 
        bytes32 merkleRoot, 
        uint256 totalAssets
    ) external onlyRoles(WITHDRAWAL_ADMIN_ROLE) returns (uint256 periodId) {
        // Cannot open a new period if one is already active
        if (_currentPeriodId != 0 && withdrawalPeriods[_currentPeriodId].active) {
            revert WithdrawalPeriodActive();
        }

        if (totalAssets == 0) revert InvalidAmount();
        if (duration == 0) revert InvalidAmount();

        // Create new period
        periodId = _nextPeriodId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        withdrawalPeriods[periodId] = WithdrawalPeriod({
            id: periodId,
            startTime: startTime,
            endTime: endTime,
            merkleRoot: merkleRoot,
            totalAssets: totalAssets,
            withdrawnAssets: 0,
            active: true
        });

        // Set as current period
        _currentPeriodId = periodId;

        emit WithdrawalPeriodOpened(periodId, startTime, endTime, merkleRoot, totalAssets);
        return periodId;
    }

    /**
     * @notice Close the current withdrawal period
     */
    function closeWithdrawalPeriod() public {
        // Can be called by anyone if period has expired, otherwise needs admin
        WithdrawalPeriod storage period = withdrawalPeriods[_currentPeriodId];

        // Check permissions
        if (!hasAnyRole(msg.sender, WITHDRAWAL_ADMIN_ROLE) && block.timestamp <= period.endTime) {
            revert Unauthorized();
        }

        if (!period.active) revert WithdrawalPeriodInactive();

        // Mark period as inactive
        period.active = false;
        period.endTime = block.timestamp;

        emit WithdrawalPeriodClosed(_currentPeriodId, block.timestamp, period.withdrawnAssets);
    }

    /**
     * @notice Approve withdrawal requests for the next period
     * @param requestIds The IDs of the withdrawal requests to approve
     */
    function approveWithdrawals(uint256[] calldata requestIds) external onlyRoles(WITHDRAWAL_ADMIN_ROLE) {
        // Ensure no active period
        if (_currentPeriodId != 0 && withdrawalPeriods[_currentPeriodId].active) {
            revert WithdrawalPeriodActive();
        }

        uint256 nextPeriodId = _nextPeriodId;

        for (uint256 i = 0; i < requestIds.length; i++) {
            uint256 requestId = requestIds[i];
            WithdrawalRequest storage request = withdrawalRequests[requestId];

            // Skip invalid or already executed requests
            if (request.id == 0 || request.executed) continue;

            // Mark as approved
            request.approved = true;
        }

        emit WithdrawalsApproved(nextPeriodId, requestIds);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get a withdrawal request by ID
     * @param requestId The ID of the withdrawal request
     * @return request The withdrawal request details
     */
    function getWithdrawalRequest(uint256 requestId) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }

    /**
     * @notice Get the current active withdrawal period
     * @return period The current withdrawal period details
     */
    function getCurrentWithdrawalPeriod() external view returns (WithdrawalPeriod memory) {
        return withdrawalPeriods[_currentPeriodId];
    }

    /**
     * @notice Get all pending withdrawal requests for a user
     * @param user The user address
     * @return requests Array of pending withdrawal requests
     */
    function getPendingWithdrawalRequests(address user) external view returns (WithdrawalRequest[] memory) {
        uint256[] memory requestIds = userWithdrawalRequests[user];

        // Count valid pending requests
        uint256 pendingCount = 0;
        for (uint256 i = 0; i < requestIds.length; i++) {
            WithdrawalRequest memory request = withdrawalRequests[requestIds[i]];
            if (request.id != 0 && !request.executed) {
                pendingCount++;
            }
        }

        // Create result array
        WithdrawalRequest[] memory result = new WithdrawalRequest[](pendingCount);

        // Fill result array
        uint256 index = 0;
        for (uint256 i = 0; i < requestIds.length; i++) {
            WithdrawalRequest memory request = withdrawalRequests[requestIds[i]];
            if (request.id != 0 && !request.executed) {
                result[index] = request;
                index++;
            }
        }

        return result;
    }

    /**
     * @notice Check if a withdrawal is valid based on the merkle proof
     * @param requestId The ID of the withdrawal request
     * @param merkleProof The merkle proof to validate
     * @return valid Whether the withdrawal is valid
     */
    function isValidWithdrawal(uint256 requestId, bytes32[] calldata merkleProof) public view returns (bool) {
        WithdrawalRequest memory request = withdrawalRequests[requestId];
        WithdrawalPeriod memory period = withdrawalPeriods[_currentPeriodId];

        if (request.id == 0 || !period.active) return false;

        // Compute the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(requestId, request.user, request.assets));

        // Verify the proof
        return MerkleProofLib.verify(merkleProof, period.merkleRoot, leaf);
    }

    /**
     * @notice Check if an address has a specific role
     * @param user The address to check
     * @param role The role to check
     * @return hasRole Whether the address has the role
     */
    function hasRole(address user, uint256 role) public view returns (bool) {
        return OwnableRoles.hasRole(user, role);
    }

    /**
     * @notice Grant a role to an address
     * @param user The address to grant the role to
     * @param role The role to grant
     */
    function grantRole(address user, uint256 role) external onlyOwner {
        _grantRoles(user, role);
    }

    /**
     * @notice Revoke a role from an address
     * @param user The address to revoke the role from
     * @param role The role to revoke
     */
    function revokeRole(address user, uint256 role) external onlyOwner {
        _revokeRoles(user, role);
    }
}