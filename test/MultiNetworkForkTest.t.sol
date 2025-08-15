// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {BtcVaultStrategy} from "../src/strategy/BtcVaultStrategy.sol";
import {BtcVaultToken} from "../src/token/BtcVaultToken.sol";
import {PriceOracleReporter} from "../src/reporter/PriceOracleReporter.sol";
import {NetworkConfig} from "../src/lib/NetworkConfig.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title MultiNetworkForkTest
 * @notice Tests BTC Vault deployment across multiple network forks
 * @dev Run with specific network: forge test --match-contract MultiNetworkForkTest --fork-url <RPC_URL>
 */
contract MultiNetworkForkTest is Test {
    BtcVaultStrategy public strategy;
    BtcVaultToken public token;
    PriceOracleReporter public oracle;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user = address(0x3);

    uint256 public chainId;
    NetworkConfig.Network public networkConfig;
    NetworkConfig.CollateralConfig[] internal collaterals;

    function setUp() public {
        // Get current chain ID from fork
        chainId = block.chainid;

        // Skip if not a supported network
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            console2.log("Skipping tests - network not supported:", chainId);
            return;
        }

        // Load network configuration
        networkConfig = NetworkConfig.getNetworkConfig(chainId);
        // Note: collaterals are fetched directly when needed to avoid storage issues

        console2.log("Testing on network:", networkConfig.name);
        console2.log("Chain ID:", chainId);

        // Deploy contracts
        _deployContracts();

        // Configure collaterals
        _configureCollaterals();
    }

    function _deployContracts() internal {
        // Deploy oracle
        oracle = new PriceOracleReporter(
            1e18, // Initial price per share
            admin,
            1000, // Max deviation (10%)
            300 // Time period (5 min)
        );

        // Deploy strategy
        strategy = new BtcVaultStrategy();

        // Get first collateral as sovaBTC or use zero address
        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        address sovaBTC = _collaterals.length > 0 ? _collaterals[0].tokenAddress : address(0);

        // Deploy token
        token = new BtcVaultToken("sovaBTC", "sovaBTC", sovaBTC, address(strategy));

        // Initialize strategy
        bytes memory initData = abi.encode(address(oracle));
        strategy.initialize("BTC Vault Strategy", "BTC-VAULT", admin, manager, sovaBTC, 8, initData);
    }

    function _configureCollaterals() internal {
        vm.startPrank(manager);

        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < _collaterals.length; i++) {
            if (_collaterals[i].tokenAddress != address(0)) {
                strategy.addCollateral(_collaterals[i].tokenAddress, _collaterals[i].decimals);
            }
        }

        vm.stopPrank();
    }

    function test_NetworkConfiguration() public {
        // Skip if not supported
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            return;
        }

        console2.log("\n=== Network Configuration Test ===");
        console2.log("Network:", networkConfig.name);
        console2.log("Oracle:", networkConfig.btcOracle);
        console2.log("Confirmations:", networkConfig.confirmations);

        // Oracle is set during initialization

        // Verify token is set correctly
        assertEq(address(strategy.sToken()), address(token));

        // Verify strategy in token
        assertEq(address(token.strategy()), address(strategy));
    }

    function test_CollateralConfiguration() public {
        // Skip if not supported
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            return;
        }

        console2.log("\n=== Collateral Configuration Test ===");

        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < _collaterals.length; i++) {
            NetworkConfig.CollateralConfig memory collateral = _collaterals[i];

            if (collateral.tokenAddress == address(0)) {
                console2.log("Skipping", collateral.symbol, "- not available");
                continue;
            }

            console2.log("Testing", collateral.symbol);
            console2.log("  Address:", collateral.tokenAddress);

            // Check if collateral is supported
            bool isSupported = strategy.supportedAssets(collateral.tokenAddress);
            assertTrue(isSupported, "Collateral should be supported");

            // Check if token contract exists (only on mainnet forks)
            if (chainId != 84532 && chainId != 11155111) {
                // Skip testnet checks
                uint256 codeSize;
                address tokenAddr = collateral.tokenAddress;
                assembly {
                    codeSize := extcodesize(tokenAddr)
                }
                assertGt(codeSize, 0, "Token contract should exist");
            }
        }
    }

    function test_DepositWithCollateral() public {
        // Skip if not supported or on testnet
        if (!NetworkConfig.isNetworkSupported(chainId) || chainId == 84532 || chainId == 11155111) {
            return;
        }

        console2.log("\n=== Deposit Test ===");

        // Find a collateral with non-zero address
        NetworkConfig.CollateralConfig memory testCollateral;
        bool found = false;

        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < _collaterals.length; i++) {
            if (_collaterals[i].tokenAddress != address(0)) {
                testCollateral = _collaterals[i];
                found = true;
                break;
            }
        }

        if (!found) {
            console2.log("No collateral available for testing");
            return;
        }

        console2.log("Testing deposit with", testCollateral.symbol);

        // Get token contract
        IERC20 collateralToken = IERC20(testCollateral.tokenAddress);

        // Find a whale address (address with tokens)
        // This would need to be configured per network/token
        address whale = _findWhale(testCollateral.tokenAddress);

        if (whale == address(0)) {
            console2.log("No whale found for", testCollateral.symbol);
            return;
        }

        uint256 whaleBalance = collateralToken.balanceOf(whale);
        console2.log("Whale balance:", whaleBalance);

        if (whaleBalance == 0) {
            console2.log("Whale has no tokens");
            return;
        }

        // Calculate deposit amount (1% of whale balance or 1 token)
        uint256 depositAmount = whaleBalance / 100;
        if (depositAmount == 0) {
            depositAmount = 10 ** testCollateral.decimals;
        }

        console2.log("Deposit amount:", depositAmount);

        // Add liquidity to strategy
        vm.prank(manager);
        strategy.addLiquidity(depositAmount);

        // Perform deposit
        vm.startPrank(whale);
        collateralToken.approve(address(strategy), depositAmount);

        uint256 sharesBefore = token.balanceOf(whale);
        strategy.depositCollateral(testCollateral.tokenAddress, depositAmount);
        uint256 sharesAfter = token.balanceOf(whale);

        vm.stopPrank();

        // Verify shares were minted
        assertGt(sharesAfter, sharesBefore, "Shares should be minted");
        console2.log("Shares minted:", sharesAfter - sharesBefore);
    }

    function test_GasEstimation() public {
        // Skip if not supported
        if (!NetworkConfig.isNetworkSupported(chainId)) {
            return;
        }

        console2.log("\n=== Gas Estimation ===");
        console2.log("Network:", networkConfig.name);
        console2.log("Max Fee:", networkConfig.maxFeePerGas);
        console2.log("Priority Fee:", networkConfig.maxPriorityFeePerGas);

        // Estimate deployment gas
        uint256 gasStart = gasleft();

        // Simulate deployment
        PriceOracleReporter tempOracle = new PriceOracleReporter(1e18, admin, 1000, 300);
        BtcVaultStrategy tempStrategy = new BtcVaultStrategy();
        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        address sovaBTC = _collaterals.length > 0 ? _collaterals[0].tokenAddress : address(0);
        BtcVaultToken tempToken = new BtcVaultToken("sovaBTC", "sovaBTC", sovaBTC, address(tempStrategy));

        uint256 gasUsed = gasStart - gasleft();
        uint256 estimatedCost = gasUsed * networkConfig.maxFeePerGas;

        console2.log("Deployment gas used:", gasUsed);
        console2.log("Estimated cost (wei):", estimatedCost);
        console2.log("Estimated cost (ether):", estimatedCost / 1e18);
    }

    function _findWhale(address tokenAddress) internal pure returns (address) {
        // Known whale addresses for different tokens on different networks
        // These would need to be maintained and updated

        // WBTC on Ethereum
        if (tokenAddress == 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) {
            return 0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656; // Aave WBTC pool
        }

        // WBTC on Arbitrum
        if (tokenAddress == 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f) {
            return 0xC7d87FAC3209b9e1a2249346C367f0CC638e8c02; // Known WBTC holder
        }

        // Add more whales as needed

        return address(0);
    }
}

/**
 * @title NetworkSpecificTests
 * @notice Additional tests specific to certain networks
 */
contract NetworkSpecificTests is MultiNetworkForkTest {
    function test_EthereumMainnetSpecific() public {
        if (chainId != 1) return;

        console2.log("\n=== Ethereum Mainnet Specific Tests ===");

        // Test all three collaterals are configured
        assertTrue(strategy.supportedAssets(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599), "WBTC should be supported");
        assertTrue(strategy.supportedAssets(0x18084fbA666a33d37592fA2633fD49a74DD93a88), "tBTC should be supported");
        assertTrue(strategy.supportedAssets(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf), "cbBTC should be supported");
    }

    function test_ArbitrumSpecific() public {
        if (chainId != 42161) return;

        console2.log("\n=== Arbitrum Specific Tests ===");

        // Test Arbitrum-specific settings
        assertEq(networkConfig.confirmations, 1, "Arbitrum should have 1 confirmation");
        assertLe(networkConfig.maxFeePerGas, 1 gwei, "Arbitrum gas should be low");
    }

    function test_BaseSpecific() public {
        if (chainId != 8453) return;

        console2.log("\n=== Base Specific Tests ===");

        // Test Base only has cbBTC
        assertTrue(strategy.supportedAssets(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf), "cbBTC should be supported");

        // Verify only one collateral
        uint256 collateralCount = 0;
        NetworkConfig.CollateralConfig[] memory _collaterals = NetworkConfig.getCollaterals(chainId);
        for (uint256 i = 0; i < _collaterals.length; i++) {
            if (_collaterals[i].tokenAddress != address(0)) {
                collateralCount++;
            }
        }
        assertEq(collateralCount, 1, "Base should only have 1 collateral");
    }
}
