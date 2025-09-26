// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract DeploymentConfig {
    struct NetworkConfig {
        address wbtc;
        address tbtc;
        address sovabtc;
        address protocolAdmin;
        address priceOracleUpdater;
        uint256 redemptionPeriod;
        uint256 minInvestment;
        uint256 initialNav;
    }

    struct CollateralConfig {
        address token;
        uint256 conversionRate;
        uint8 decimals;
        bool isActive;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;
    mapping(uint256 => CollateralConfig[]) public collateralConfigs;

    uint256 constant MAINNET_CHAIN_ID = 1;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 constant LOCAL_CHAIN_ID = 31337;

    constructor() {
        _setupMainnetConfig();
        _setupSepoliaConfig();
        _setupBaseSepoliaConfig();
        _setupLocalConfig();
    }

    function _setupMainnetConfig() private {
        networkConfigs[MAINNET_CHAIN_ID] = NetworkConfig({
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            tbtc: 0x18084fbA666a33d37592fA2633fD49a74DD93a88,
            sovabtc: address(0), // To be deployed
            protocolAdmin: address(0), // To be set via env
            priceOracleUpdater: address(0), // To be set via env
            redemptionPeriod: 14 days,
            minInvestment: 1e5, // 0.001 BTC in 8 decimals
            initialNav: 1e18 // 1.0 in 18 decimals
        });

        collateralConfigs[MAINNET_CHAIN_ID].push(
            CollateralConfig({
                token: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
                conversionRate: 1e18, // 1.0
                decimals: 8,
                isActive: true
            })
        );

        collateralConfigs[MAINNET_CHAIN_ID].push(
            CollateralConfig({
                token: 0x18084fbA666a33d37592fA2633fD49a74DD93a88, // TBTC
                conversionRate: 99e16, // 0.99
                decimals: 18,
                isActive: true
            })
        );
    }

    function _setupSepoliaConfig() private {
        networkConfigs[SEPOLIA_CHAIN_ID] = NetworkConfig({
            wbtc: address(0), // Deploy mock
            tbtc: address(0), // Deploy mock
            sovabtc: address(0), // Deploy mock
            protocolAdmin: address(0), // To be set via env
            priceOracleUpdater: address(0), // To be set via env
            redemptionPeriod: 14 days,
            minInvestment: 1e5, // 0.001 BTC in 8 decimals
            initialNav: 1e18 // 1.0 in 18 decimals
        });
    }

    function _setupBaseSepoliaConfig() private {
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = NetworkConfig({
            wbtc: 0xe44b2870eFcd6Bb3C9305808012621f438e9636D,
            tbtc: 0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802,
            sovabtc: 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9,
            protocolAdmin: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            priceOracleUpdater: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            redemptionPeriod: 1 days, // Shorter for testing
            minInvestment: 1e5, // 0.001 BTC in 8 decimals
            initialNav: 1e18 // 1.0 in 18 decimals
        });

        collateralConfigs[BASE_SEPOLIA_CHAIN_ID].push(
            CollateralConfig({
                token: 0xe44b2870eFcd6Bb3C9305808012621f438e9636D, // WBTC
                conversionRate: 1e18, // 1.0
                decimals: 8,
                isActive: true
            })
        );

        collateralConfigs[BASE_SEPOLIA_CHAIN_ID].push(
            CollateralConfig({
                token: 0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802, // TBTC
                conversionRate: 99e16, // 0.99
                decimals: 18,
                isActive: true
            })
        );

        collateralConfigs[BASE_SEPOLIA_CHAIN_ID].push(
            CollateralConfig({
                token: 0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9, // sovaBTC
                conversionRate: 1e18, // 1.0
                decimals: 8,
                isActive: true
            })
        );
    }

    function _setupLocalConfig() private {
        networkConfigs[LOCAL_CHAIN_ID] = NetworkConfig({
            wbtc: address(0), // Deploy mock
            tbtc: address(0), // Deploy mock
            sovabtc: address(0), // Deploy mock
            protocolAdmin: address(0), // To be set via env
            priceOracleUpdater: address(0), // To be set via env
            redemptionPeriod: 14 days,
            minInvestment: 1e5, // 0.001 BTC in 8 decimals
            initialNav: 1e18 // 1.0 in 18 decimals
        });
    }

    function getNetworkConfig(uint256 chainId) public view returns (NetworkConfig memory) {
        NetworkConfig memory config = networkConfigs[chainId];

        // Override with environment variables if set
        if (config.protocolAdmin == address(0)) {
            config.protocolAdmin = _getEnvAddress("PROTOCOL_ADMIN_ADDRESS");
        }
        if (config.priceOracleUpdater == address(0)) {
            config.priceOracleUpdater = _getEnvAddress("PRICE_ORACLE_UPDATER");
        }

        return config;
    }

    function getCollateralConfigs(uint256 chainId) public view returns (CollateralConfig[] memory) {
        return collateralConfigs[chainId];
    }

    function _getEnvAddress(string memory) private pure returns (address) {
        // This will be overridden in scripts using vm.envAddress
        return address(0);
    }
}
