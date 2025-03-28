// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title TransferApproval
 * @notice Handles KYC/AML compliance for tRWA tokens
 * @dev Can be plugged into tokens to enforce transfer restrictions
 */
contract TransferApproval {
    address public admin;
    address public complianceOfficer;
    mapping(address => bool) public isKycApproved;
    mapping(address => bool) public isRegulatedToken;
    mapping(address => bool) public isExempt;
    uint256 public transferLimit;
    bool public enforceTransferLimits;

    // Events
    event TokenRegistered(address indexed token);
    event TokenUnregistered(address indexed token);
    event KycApproved(address indexed user);
    event KycRevoked(address indexed user);
    event ExemptStatusUpdated(address indexed user, bool isExempt);
    event TransferLimitUpdated(uint256 newLimit);
    event TransferLimitEnforcementUpdated(bool enforced);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event ComplianceOfficerUpdated(address indexed oldOfficer, address indexed newOfficer);

    // Errors
    error Unauthorized();
    error KycRequired();
    error TransferLimitExceeded();
    error InvalidAddress();
    error InvalidLimit();

    /**
     * @notice Contract constructor
     * @param _transferLimit Initial transfer limit in tokens
     * @param _enforceTransferLimits Whether to enforce transfer limits
     */
    constructor(uint256 _transferLimit, bool _enforceTransferLimits) {
        admin = msg.sender;
        complianceOfficer = msg.sender;
        transferLimit = _transferLimit;
        enforceTransferLimits = _enforceTransferLimits;
    }

    /**
     * @notice Modifier to restrict function calls to admin
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Modifier to restrict function calls to compliance officer
     */
    modifier onlyComplianceOfficer() {
        if (msg.sender != complianceOfficer && msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Register a token to be regulated by this transfer approver
     * @param _token Address of the token to register
     */
    function registerToken(address _token) external onlyAdmin {
        if (_token == address(0)) revert InvalidAddress();

        isRegulatedToken[_token] = true;

        emit TokenRegistered(_token);
    }

    /**
     * @notice Unregister a token from compliance regulation
     * @param _token Address of the token to unregister
     */
    function unregisterToken(address _token) external onlyAdmin {
        if (_token == address(0)) revert InvalidAddress();

        isRegulatedToken[_token] = false;

        emit TokenUnregistered(_token);
    }

    /**
     * @notice Approve KYC for a user
     * @param _user Address of the user to approve
     */
    function approveKyc(address _user) external onlyComplianceOfficer {
        if (_user == address(0)) revert InvalidAddress();

        isKycApproved[_user] = true;

        emit KycApproved(_user);
    }

    /**
     * @notice Revoke KYC for a user
     * @param _user Address of the user to revoke KYC from
     */
    function revokeKyc(address _user) external onlyComplianceOfficer {
        if (_user == address(0)) revert InvalidAddress();

        isKycApproved[_user] = false;

        emit KycRevoked(_user);
    }

    /**
     * @notice Batch approve KYC for multiple users
     * @param _users Array of addresses to approve
     */
    function batchApproveKyc(address[] calldata _users) external onlyComplianceOfficer {
        for (uint256 i = 0; i < _users.length; i++) {
            if (_users[i] == address(0)) revert InvalidAddress();

            isKycApproved[_users[i]] = true;

            emit KycApproved(_users[i]);
        }
    }

    /**
     * @notice Update exempt status for a user (exempt from KYC)
     * @param _user Address of the user
     * @param _isExempt Whether the user is exempt
     */
    function updateExemptStatus(address _user, bool _isExempt) external onlyComplianceOfficer {
        if (_user == address(0)) revert InvalidAddress();

        isExempt[_user] = _isExempt;

        emit ExemptStatusUpdated(_user, _isExempt);
    }

    /**
     * @notice Update the transfer limit
     * @param _newLimit New transfer limit in tokens
     */
    function updateTransferLimit(uint256 _newLimit) external onlyComplianceOfficer {
        if (_newLimit == 0) revert InvalidLimit();

        transferLimit = _newLimit;

        emit TransferLimitUpdated(_newLimit);
    }

    /**
     * @notice Enable or disable transfer limit enforcement
     * @param _enforce Whether to enforce transfer limits
     */
    function setTransferLimitEnforcement(bool _enforce) external onlyComplianceOfficer {
        enforceTransferLimits = _enforce;

        emit TransferLimitEnforcementUpdated(_enforce);
    }

    /**
     * @notice Update the admin address
     * @param _newAdmin Address of the new admin
     */
    function updateAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAddress();

        address oldAdmin = admin;
        admin = _newAdmin;

        emit AdminUpdated(oldAdmin, _newAdmin);
    }

    /**
     * @notice Update the compliance officer address
     * @param _newOfficer Address of the new compliance officer
     */
    function updateComplianceOfficer(address _newOfficer) external onlyAdmin {
        if (_newOfficer == address(0)) revert InvalidAddress();

        address oldOfficer = complianceOfficer;
        complianceOfficer = _newOfficer;

        emit ComplianceOfficerUpdated(oldOfficer, _newOfficer);
    }

    /**
     * @notice Check if a transfer is compliant
     * @param _token Address of the token
     * @param _from Address sending tokens
     * @param _to Address receiving tokens
     * @param _amount Amount of tokens being transferred
     * @return approved Whether the transfer is approved
     */
    function checkTransferApproval(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool approved) {
        // Skip compliance checks if token is not regulated
        if (!isRegulatedToken[_token]) {
            return true;
        }

        // Check KYC status for sender and receiver, unless exempt
        if (!isExempt[_from] && !isKycApproved[_from]) {
            return false;
        }

        if (!isExempt[_to] && !isKycApproved[_to]) {
            return false;
        }

        // Check transfer limits if enforced
        if (enforceTransferLimits && _amount > transferLimit) {
            return false;
        }

        return true;
    }
}