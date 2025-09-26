// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title MockBTC
 * @notice Test BTC token with public mint function for testing
 * @dev Uses 8 decimals to match BTC standard
 */
contract MockBTC is ERC20, Ownable {
    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    string private _name;
    string private _symbol;
    uint256 public constant MAX_MINT_PER_TX = 10 * 10 ** 8; // 10 BTC max per mint

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _initializeOwner(msg.sender);

        // Mint initial supply to deployer
        _mint(msg.sender, 1000 * 10 ** 8); // 1000 BTC
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return 8; // BTC standard
    }

    /*//////////////////////////////////////////////////////////////
                            MINT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Public mint function for testing
     * @param amount Amount to mint (max 10 BTC per tx)
     */
    function mint(uint256 amount) external {
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per tx");
        _mint(msg.sender, amount);
    }

    /**
     * @notice Mint to specific address (for testing)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mintTo(address to, uint256 amount) external {
        require(amount <= MAX_MINT_PER_TX, "Exceeds max mint per tx");
        _mint(to, amount);
    }

    /**
     * @notice Faucet function for easy testing
     * @dev Mints 1 BTC to caller
     */
    function faucet() external {
        _mint(msg.sender, 1 * 10 ** 8); // 1 BTC
    }

    /**
     * @notice Owner can mint any amount
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
