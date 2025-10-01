// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title SovaBTCv1
 * @notice Upgradeable ERC20 token with admin-controlled minting, burning, and upgradeability
 * @dev Uses UUPS upgrade pattern with 8 decimals to match WBTC, includes EIP-2612 permit functionality
 */
contract SovaBTCv1 is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    error Unauthorized();
    error InvalidAddress();

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    address public admin;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert Unauthorized();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with name, symbol, and admin
     * @param _admin The address that will have admin privileges
     */
    function initialize(address _admin) public initializer {
        if (_admin == address(0)) {
            revert InvalidAddress();
        }

        __ERC20_init("Sova BTC v1", "SOVABTCV1");
        __ERC20Permit_init("Sova BTC v1");
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        admin = _admin;
        emit AdminChanged(address(0), _admin);
    }

    /**
     * @notice Returns the version of the contract
     * @return string The version string
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @notice Returns the number of decimals used by the token
     * @return uint8 The number of decimals (8, matching WBTC)
     */
    function decimals() public pure override returns (uint8) {
        return 8;
    }

    /**
     * @notice Mints new tokens to a specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyAdmin {
        if (to == address(0)) {
            revert InvalidAddress();
        }
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @notice Burns tokens from a specified address (admin only, for emergency situations)
     * @dev This is a privileged function that bypasses allowances. Use with caution.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function adminBurn(address from, uint256 amount) external onlyAdmin {
        _burn(from, amount);
        emit Burn(from, amount);
    }

    /**
     * @notice Burns tokens from the caller's address
     * @dev Anyone can burn their own tokens. This permanently reduces the total supply.
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specified address using the allowance mechanism
     * @dev Requires the caller to have sufficient allowance from the `from` address.
     *      This follows the standard ERC20 approval pattern for burning.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit Burn(from, amount);
    }

    /**
     * @notice Changes the admin address
     * @param newAdmin The address of the new admin
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        address previousAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(previousAdmin, newAdmin);
    }

    /**
     * @notice Pauses all token transfers
     * @dev Can only be called by admin. When paused, all transfers, mints, and burns are blocked.
     *      This is an emergency mechanism to protect users in case of security issues.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers
     * @dev Can only be called by admin. Restores normal token functionality after a pause.
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @notice Recovers ERC20 tokens accidentally sent to this contract
     * @dev Can only be called by admin. Allows rescue of tokens airdropped to the contract address.
     * @param token The address of the ERC20 token to recover
     * @param to The address to send the recovered tokens to
     * @param amount The amount of tokens to recover
     */
    function recoverTokens(address token, address to, uint256 amount) external onlyAdmin nonReentrant {
        if (to == address(0)) {
            revert InvalidAddress();
        }
        IERC20(token).transfer(to, amount);
        emit TokensRecovered(token, to, amount);
    }

    /**
     * @notice Hook that is called before any transfer of tokens
     * @dev Includes minting and burning. Enforces pause functionality.
     * @param from The address tokens are transferred from (address(0) for minting)
     * @param to The address tokens are transferred to (address(0) for burning)
     * @param amount The amount of tokens being transferred
     */
    function _update(address from, address to, uint256 amount) internal override whenNotPaused {
        super._update(from, to, amount);
    }

    /**
     * @notice Authorizes an upgrade to a new implementation
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /**
     * @dev Storage gap for future upgrades
     */
    uint256[50] private __gap;
}
