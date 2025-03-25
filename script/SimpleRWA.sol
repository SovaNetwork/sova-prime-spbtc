// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title SimpleRWA
 * @notice Simplified RWA token for testing
 */
contract SimpleRWA {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public owner;
    uint256 public underlyingPerToken; // Value of underlying asset per token in USD (18 decimals)

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event UnderlyingValueUpdated(uint256 newUnderlyingPerToken, uint256 timestamp);

    /**
     * @notice Constructor
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialUnderlyingPerToken Initial value of underlying asset per token in USD (18 decimals)
     */
    constructor(string memory _name, string memory _symbol, uint256 _initialUnderlyingPerToken) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        underlyingPerToken = _initialUnderlyingPerToken;
    }

    /**
     * @notice Only owner modifier
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    /**
     * @notice Transfer tokens to another address
     * @param _to Recipient address
     * @param _value Amount to transfer
     * @return success Whether the transfer was successful
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid recipient");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Approve spender to transfer tokens on behalf of the sender
     * @param _spender Address allowed to spend
     * @param _value Amount approved
     * @return success Whether the approval was successful
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Invalid spender");

        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param _from Source address
     * @param _to Destination address
     * @param _value Amount to transfer
     * @return success Whether the transfer was successful
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0) && _to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice Mint new tokens (only owner)
     * @param _to Recipient address
     * @param _amount Amount to mint
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "Invalid recipient");

        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @notice Burn tokens (only owner)
     * @param _from Address to burn from
     * @param _amount Amount to burn
     */
    function burn(address _from, uint256 _amount) public onlyOwner {
        require(_from != address(0), "Invalid address");
        require(balanceOf[_from] >= _amount, "Insufficient balance");

        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_from, address(0), _amount);
    }

    /**
     * @notice Update underlying value per token (only owner)
     * @param _newUnderlyingPerToken New underlying value per token in USD (18 decimals)
     */
    function updateUnderlyingValue(uint256 _newUnderlyingPerToken) public onlyOwner {
        require(_newUnderlyingPerToken > 0, "Invalid underlying value");

        underlyingPerToken = _newUnderlyingPerToken;
        emit UnderlyingValueUpdated(_newUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Calculate the USD value of shares
     * @param _shares Number of shares
     * @return usdValue USD value of shares (18 decimals)
     */
    function getUsdValue(uint256 _shares) public view returns (uint256 usdValue) {
        return (_shares * underlyingPerToken) / 1e18;
    }
}