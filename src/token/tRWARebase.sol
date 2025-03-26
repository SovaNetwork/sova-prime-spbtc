// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title tRWARebase
 * @notice Tokenized Real World Asset (tRWA) with rebasing token accounting model
 * @dev Token balances rebase automatically with underlying asset value changes
 */
contract tRWARebase {
    // ERC20 standard variables
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) public allowance;

    // Rebasing mechanism
    uint256 private _underlyingValue; // Total underlying value in USD (18 decimals)
    uint256 private _sharesTotalSupply; // Internal static share accounting
    mapping(address => uint256) private _shares; // Internal shares tracking

    // Administrative variables
    address public oracle;
    address public admin;
    address public complianceModule;
    uint256 public lastValueUpdate; // Timestamp of last underlying value update
    bool public complianceEnabled = false;

    // Events for ERC20
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Rebasing events
    event Rebase(uint256 newUnderlyingValue, uint256 oldUnderlyingValue, uint256 timestamp);

    // Admin events
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
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidAddress();
    error ZeroShares();

    /**
     * @notice Contract constructor
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _oracle Address of the NAV oracle
     * @param _initialUnderlyingValue Initial total value of underlying assets in USD (18 decimals)
     * @param _initialSupply Initial token supply to mint to deployer
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _oracle,
        uint256 _initialUnderlyingValue,
        uint256 _initialSupply
    ) {
        if (_oracle == address(0)) revert InvalidOracleAddress();
        if (_initialUnderlyingValue == 0) revert InvalidUnderlyingValue();
        if (_initialSupply == 0) revert ZeroShares();

        name = _name;
        symbol = _symbol;
        oracle = _oracle;
        admin = msg.sender;

        // Set up initial shares and values
        _underlyingValue = _initialUnderlyingValue;
        _sharesTotalSupply = _initialSupply;
        _shares[msg.sender] = _initialSupply;
        _totalSupply = _initialSupply;
        _balances[msg.sender] = _initialSupply;

        lastValueUpdate = block.timestamp;

        emit Transfer(address(0), msg.sender, _initialSupply);
        emit Rebase(_initialUnderlyingValue, 0, block.timestamp);
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
     * @notice Get current total supply
     * @return The current total supply after rebasing
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Get current balance of an account
     * @param _account The address to query balance for
     * @return The current token balance after rebasing
     */
    function balanceOf(address _account) public view returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Get internal shares of an account (non-rebasing)
     * @param _account The address to query shares for
     * @return The share balance (non-rebasing)
     */
    function sharesOf(address _account) public view returns (uint256) {
        return _shares[_account];
    }

    /**
     * @notice Get total shares (non-rebasing)
     * @return The total share supply (non-rebasing)
     */
    function totalShares() public view returns (uint256) {
        return _sharesTotalSupply;
    }

    /**
     * @notice Update the underlying total value, which triggers a rebase
     * @param _newUnderlyingValue New total underlying value in USD (18 decimals)
     */
    function updateUnderlyingValue(uint256 _newUnderlyingValue) external onlyOracle {
        if (_newUnderlyingValue == 0) revert InvalidUnderlyingValue();

        uint256 oldUnderlyingValue = _underlyingValue;
        _underlyingValue = _newUnderlyingValue;
        lastValueUpdate = block.timestamp;

        // Rebase total supply based on the value change
        uint256 newTotalSupply = (_newUnderlyingValue * _sharesTotalSupply) / oldUnderlyingValue;
        _totalSupply = newTotalSupply;

        emit Rebase(_newUnderlyingValue, oldUnderlyingValue, block.timestamp);
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
     * @notice Convert from shares to tokens
     * @param _sharesAmount Amount of shares
     * @return tokenAmount Amount of tokens after conversion
     */
    function _sharesToTokens(uint256 _sharesAmount) internal view returns (uint256 tokenAmount) {
        if (_sharesTotalSupply == 0) return 0;
        return (_sharesAmount * _totalSupply) / _sharesTotalSupply;
    }

    /**
     * @notice Convert from tokens to shares
     * @param _tokenAmount Amount of tokens
     * @return sharesAmount Amount of shares after conversion
     */
    function _tokensToShares(uint256 _tokenAmount) internal view returns (uint256 sharesAmount) {
        if (_totalSupply == 0) return 0;
        return (_tokenAmount * _sharesTotalSupply) / _totalSupply;
    }

    /**
     * @notice Transfer tokens to a specified address
     * @param _to The address to transfer to
     * @param _value The token amount to be transferred
     * @return success Whether the transfer was successful or not
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (_to == address(0)) revert InvalidAddress();
        if (_balances[msg.sender] < _value) revert InsufficientBalance();

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

        // Convert token amount to shares
        uint256 sharesAmount = _tokensToShares(_value);

        // Transfer shares (internal accounting)
        _shares[msg.sender] -= sharesAmount;
        _shares[_to] += sharesAmount;

        // Update balances
        _balances[msg.sender] = _sharesToTokens(_shares[msg.sender]);
        _balances[_to] = _sharesToTokens(_shares[_to]);

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
        if (_balances[_from] < _value) revert InsufficientBalance();
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

        // Convert token amount to shares
        uint256 sharesAmount = _tokensToShares(_value);

        // Transfer shares (internal accounting)
        _shares[_from] -= sharesAmount;
        _shares[_to] += sharesAmount;

        // Update balances
        _balances[_from] = _sharesToTokens(_shares[_from]);
        _balances[_to] = _sharesToTokens(_shares[_to]);

        // Reduce allowance
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice Mint new tokens to an address (admin only)
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyAdmin {
        if (_to == address(0)) revert InvalidAddress();

        // Convert token amount to shares
        uint256 sharesAmount = _tokensToShares(_amount);
        if (sharesAmount == 0) revert ZeroShares();

        // Mint shares (internal accounting)
        _shares[_to] += sharesAmount;
        _sharesTotalSupply += sharesAmount;

        // Update balances and total supply
        _balances[_to] = _sharesToTokens(_shares[_to]);
        _totalSupply += _amount;

        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @notice Burn tokens from an address (admin only)
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyAdmin {
        if (_from == address(0)) revert InvalidAddress();
        if (_balances[_from] < _amount) revert InsufficientBalance();

        // Convert token amount to shares
        uint256 sharesAmount = _tokensToShares(_amount);

        // Burn shares (internal accounting)
        _shares[_from] -= sharesAmount;
        _sharesTotalSupply -= sharesAmount;

        // Update balances and total supply
        _balances[_from] = _sharesToTokens(_shares[_from]);
        _totalSupply -= _amount;

        emit Transfer(_from, address(0), _amount);
    }

    /**
     * @notice Get the current underlying value
     * @return value Current underlying total value in USD (18 decimals)
     */
    function getUnderlyingValue() public view returns (uint256 value) {
        return _underlyingValue;
    }

    /**
     * @notice Calculate the USD value of a given number of tokens
     * @param _tokens Number of tokens
     * @return usdValue USD value of the tokens (18 decimals)
     */
    function getUsdValue(uint256 _tokens) public view returns (uint256 usdValue) {
        if (_totalSupply == 0) return 0;
        return (_tokens * _underlyingValue) / _totalSupply;
    }
}