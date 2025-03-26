// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) with share-based accounting model
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA {
    // ERC20 standard variables
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Events for ERC20
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    address public oracle;
    address public admin;
    address public complianceModule;
    uint256 public underlyingPerToken; // Value of underlying asset per token in USD (18 decimals)
    uint256 public lastValueUpdate; // Timestamp of last underlying value update
    bool public complianceEnabled = false;

    // Events
    event UnderlyingValueUpdated(uint256 newUnderlyingPerToken, uint256 timestamp);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event ComplianceModuleUpdated(address indexed oldModule, address indexed newModule);
    event ComplianceToggled(bool enabled);
    event TransferRejected(address indexed from, address indexed to, uint256 value, string reason);

    // Errors
    error Unauthorized();
    error InvalidUnderlyingValue();
    error InvalidOracleAddress();
    error InvalidAdminAddress();
    error InvalidComplianceModuleAddress();
    error TransferBlocked(string reason);

    /**
     * @notice Contract constructor
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _oracle Address of the NAV oracle
     * @param _initialUnderlyingPerToken Initial value of underlying asset per token in USD (18 decimals)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        uint256 _initialUnderlyingPerToken
    ) {
        if (_oracle == address(0)) revert InvalidOracleAddress();
        if (_initialUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        name = _name;
        symbol = _symbol;
        oracle = _oracle;
        admin = msg.sender;
        underlyingPerToken = _initialUnderlyingPerToken;
        lastValueUpdate = block.timestamp;

        emit UnderlyingValueUpdated(_initialUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Modifier to restrict function calls to authorized addresses
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Modifier to restrict function calls to the oracle
     */
    modifier onlyOracle() {
        if (msg.sender != oracle) revert Unauthorized();
        _;
    }

    /**
     * @notice Update the underlying value per token
     * @param _newUnderlyingPerToken New underlying value per token in USD (18 decimals)
     */
    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) external onlyOracle {
        if (_newUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        underlyingPerToken = _newUnderlyingPerToken;
        lastValueUpdate = block.timestamp;

        emit UnderlyingValueUpdated(_newUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Update the oracle address
     * @param _newOracle Address of the new oracle
     */
    function updateOracle(address _newOracle) external onlyAdmin {
        if (_newOracle == address(0)) revert InvalidOracleAddress();

        address oldOracle = oracle;
        oracle = _newOracle;

        emit OracleUpdated(oldOracle, _newOracle);
    }

    /**
     * @notice Update the admin address
     * @param _newAdmin Address of the new admin
     */
    function updateAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAdminAddress();

        address oldAdmin = admin;
        admin = _newAdmin;

        emit AdminUpdated(oldAdmin, _newAdmin);
    }

    /**
     * @notice Set or update the compliance module
     * @param _complianceModule Address of the compliance module
     */
    function setComplianceModule(address _complianceModule) external onlyAdmin {
        if (_complianceModule == address(0)) revert InvalidComplianceModuleAddress();

        address oldModule = complianceModule;
        complianceModule = _complianceModule;

        emit ComplianceModuleUpdated(oldModule, _complianceModule);
    }

    /**
     * @notice Enable or disable compliance checks
     * @param _enabled Whether compliance is enabled
     */
    function toggleCompliance(bool _enabled) external onlyAdmin {
        complianceEnabled = _enabled;

        emit ComplianceToggled(_enabled);
    }

    /**
     * @notice Transfer tokens to a specified address
     * @param _to The address to transfer to
     * @param _value The amount to be transferred
     * @return success Whether the transfer was successful or not
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (_to == address(0)) revert InvalidAddress();
        if (balanceOf[msg.sender] < _value) revert InsufficientBalance();

        // Check compliance if enabled
        if (complianceEnabled && complianceModule != address(0)) {
            // Interface to the checkTransferCompliance function
            (bool successCall, bytes memory data) = complianceModule.staticcall(
                abi.encodeWithSignature(
                    "checkTransferCompliance(address,address,address,uint256)",
                    address(this),
                    msg.sender,
                    _to,
                    _value
                )
            );

            if (!successCall || !abi.decode(data, (bool))) {
                emit TransferRejected(msg.sender, _to, _value, "Failed compliance check");
                revert TransferBlocked("Failed compliance check");
            }
        }

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Approve the passed address to spend the specified amount of tokens on behalf of msg.sender
     * @param _spender The address which will spend the funds
     * @param _value The amount of tokens to be spent
     * @return success Whether the approval was successful or not
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        if (_spender == address(0)) revert InvalidAddress();

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param _from The address to transfer from
     * @param _to The address to transfer to
     * @param _value The amount to be transferred
     * @return success Whether the transfer was successful or not
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (_from == address(0) || _to == address(0)) revert InvalidAddress();
        if (balanceOf[_from] < _value) revert InsufficientBalance();
        if (allowance[_from][msg.sender] < _value) revert InsufficientAllowance();

        // Check compliance if enabled
        if (complianceEnabled && complianceModule != address(0)) {
            // Interface to the checkTransferCompliance function
            (bool successCall, bytes memory data) = complianceModule.staticcall(
                abi.encodeWithSignature(
                    "checkTransferCompliance(address,address,address,uint256)",
                    address(this),
                    _from,
                    _to,
                    _value
                )
            );

            if (!successCall || !abi.decode(data, (bool))) {
                emit TransferRejected(_from, _to, _value, "Failed compliance check");
                revert TransferBlocked("Failed compliance check");
            }
        }

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice Mint new shares to an address
     * @param _to Address to mint shares to
     * @param _amount Amount of shares to mint
     */
    function mint(address _to, uint256 _amount) external onlyAdmin {
        if (_to == address(0)) revert InvalidAddress();

        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @notice Burn shares from an address
     * @param _from Address to burn shares from
     * @param _amount Amount of shares to burn
     */
    function burn(address _from, uint256 _amount) external onlyAdmin {
        if (_from == address(0)) revert InvalidAddress();
        if (balanceOf[_from] < _amount) revert InsufficientBalance();

        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_from, address(0), _amount);
    }

    /**
     * @notice Calculate the USD value of a given number of shares
     * @param _shares Number of shares
     * @return usdValue USD value of the shares (18 decimals)
     */
    function getUsdValue(uint256 _shares) public view returns (uint256 usdValue) {
        return (_shares * underlyingPerToken) / 1e18;
    }

    // Additional Errors
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAddress();
}