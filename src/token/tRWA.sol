// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from "solady/tokens/ERC4626.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/**
 * @title tRWA
 * @notice Tokenized Real World Asset (tRWA) inheriting ERC4626 standard
 * @dev Each token represents a share in the underlying real-world fund
 */
contract tRWA is ERC4626 {
    using FixedPointMathLib for uint256;

    // Internal storage for token metadata
    string internal _name;
    string internal _symbol;

    address public oracle;
    address public admin;
    address public complianceModule;
    uint256 public underlyingPerToken; // Value of underlying asset per token in USD (18 decimals)
    uint256 public lastValueUpdate; // Timestamp of last underlying value update
    bool public complianceEnabled = false;

    // Asset-related state
    uint256 public totalUnderlying; // Total value of underlying assets in USD (18 decimals)

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
    error ZeroAssets();
    error ZeroShares();

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

        _name = name_;
        _symbol = symbol_;
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
     * @notice Returns the asset address, which is address(0) as we use synthetic USD value
     */
    function asset() public view virtual override returns (address) {
        return address(0); // Synthetic USD value representation
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

        // Calculate the total underlying value based on current shares
        uint256 supply = totalSupply();
        if (supply > 0) {
            totalUnderlying = supply * _newUnderlyingPerToken / 1e18;
        }

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

    /*//////////////////////////////////////////////////////////////
                            ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of the underlying assets managed by the vault
     * @return assets Total underlying assets in USD value (18 decimals)
     */
    function totalAssets() public view override returns (uint256 assets) {
        return totalUnderlying;
    }

    /**
     * @notice Deposit assets and mint shares to receiver, only callable by admin
     * @param assets Amount of assets to deposit
     * @param receiver Address receiving the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override onlyAdmin returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroShares();

        // Update the total underlying assets
        totalUnderlying += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Mint shares to receiver by depositing assets, only callable by admin
     * @param shares Amount of shares to mint
     * @param receiver Address receiving the shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver) public override onlyAdmin returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        assets = previewMint(shares);
        if (assets == 0) revert ZeroAssets();

        // Update the total underlying assets
        totalUnderlying += assets;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Withdraw assets by burning shares, only callable by admin
     * @param assets Amount of assets to withdraw
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) public override onlyAdmin returns (uint256 shares) {
        if (receiver == address(0)) revert InvalidAddress();
        if (assets == 0) revert ZeroAssets();

        shares = previewWithdraw(assets);
        if (shares == 0) revert ZeroShares();

        if (shares > balanceOf(owner))
            revert WithdrawMoreThanMax();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Redeem shares for assets, only callable by admin
     * @param shares Amount of shares to redeem
     * @param receiver Address receiving the assets
     * @param owner Address owning the shares
     * @return assets Amount of assets received
     */
    function redeem(uint256 shares, address receiver, address owner) public override onlyAdmin returns (uint256 assets) {
        if (receiver == address(0)) revert InvalidAddress();
        if (shares == 0) revert ZeroShares();

        if (shares > balanceOf(owner))
            revert RedeemMoreThanMax();

        assets = previewRedeem(shares);
        if (assets == 0) revert ZeroAssets();

        // Update the total underlying assets
        totalUnderlying -= assets;

        // Burn shares from owner
        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Calculate the USD value of a given number of shares
     * @param _shares Number of shares
     * @return usdValue USD value of the shares (18 decimals)
     */
    function getUsdValue(uint256 _shares) public view returns (uint256 usdValue) {
        return convertToAssets(_shares);
    }
}