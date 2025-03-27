// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) with share-based accounting model
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC20 {
    // Internal storage for token metadata
    string internal _name;
    string internal _symbol;

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
    error InvalidAddress();

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param _oracle Address of the NAV oracle
     * @param _initialUnderlyingPerToken Initial value of underlying asset per token in USD (18 decimals)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address _oracle,
        uint256 _initialUnderlyingPerToken
    ) {
        if (_oracle == address(0)) revert InvalidOracleAddress();
        if (_initialUnderlyingPerToken == 0) revert InvalidUnderlyingValue();

        admin = msg.sender;
        oracle = _oracle;
        underlyingPerToken = _initialUnderlyingPerToken;
        lastValueUpdate = block.timestamp;

        emit UnderlyingValueUpdated(_initialUnderlyingPerToken, block.timestamp);
    }

    /**
     * @notice Returns the name of the token
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the decimals places of the token
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
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
     * @notice Override _beforeTokenTransfer to add compliance checks
     * @dev Called before any transfer, mint, or burn
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // Skip checks for minting and burning which are controlled by admin
        if (from != address(0) && to != address(0)) {
            if (to == address(0)) revert InvalidAddress();

            // Check compliance if enabled
            if (complianceEnabled && complianceModule != address(0)) {
                // Interface to the checkTransferCompliance function
                (bool successCall, bytes memory data) = complianceModule.staticcall(
                    abi.encodeWithSignature(
                        "checkTransferCompliance(address,address,address,uint256)",
                        address(this),
                        from,
                        to,
                        amount
                    )
                );

                if (!successCall || !abi.decode(data, (bool))) {
                    emit TransferRejected(from, to, amount, "Failed compliance check");
                    revert TransferBlocked("Failed compliance check");
                }
            }
        }
    }

    /**
     * @notice Mint new shares to an address
     * @param _to Address to mint shares to
     * @param _amount Amount of shares to mint
     */
    function mint(address _to, uint256 _amount) external onlyAdmin {
        if (_to == address(0)) revert InvalidAddress();
        _mint(_to, _amount);
    }

    /**
     * @notice Burn shares from an address
     * @param _from Address to burn shares from
     * @param _amount Amount of shares to burn
     */
    function burn(address _from, uint256 _amount) external onlyAdmin {
        if (_from == address(0)) revert InvalidAddress();

        // Check balance before burning
        if (balanceOf(_from) < _amount) {
            // Use the ERC20 InsufficientBalance error from the parent contract
            revert ERC20.InsufficientBalance();
        }

        _burn(_from, _amount);
    }

    /**
     * @notice Calculate the USD value of a given number of shares
     * @param _shares Number of shares
     * @return usdValue USD value of the shares (18 decimals)
     */
    function getUsdValue(uint256 _shares) public view returns (uint256 usdValue) {
        return (_shares * underlyingPerToken) / 1e18;
    }
}