# Multi-Collateral BTC Vault System

A sophisticated ERC4626-compatible vault system for Bitcoin-pegged assets, built on the FountFi protocol framework. This system enables users to deposit various forms of wrapped Bitcoin (WBTC, TBTC, sovaBTC) and receive vault shares representing their ownership stake.

## 🚀 Live Deployment

### Base Sepolia Testnet (Current)

| Contract | Address | Explorer |
|----------|---------|----------|
| **BtcVaultStrategy** | `0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8` | [View on BaseScan](https://sepolia.basescan.org/address/0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8) |
| **BtcVaultToken** | `0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a` | [View on BaseScan](https://sepolia.basescan.org/address/0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a) |
| **PriceOracleReporter** | `0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF` | [View on BaseScan](https://sepolia.basescan.org/address/0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF) |

### Supported Collateral Tokens

| Token | Address | Decimals |
|-------|---------|----------|
| **WBTC** | `0xe44b2870eFcd6Bb3C9305808012621f438e9636D` | 8 |
| **TBTC** | `0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802` | 8 |
| **sovaBTC** | `0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9` | 8 |

## 📊 System Overview

The Multi-Collateral BTC Vault system provides:

- **Multi-collateral deposits**: Accept WBTC, TBTC, and sovaBTC
- **Unified redemptions**: All withdrawals in sovaBTC only
- **Managed withdrawals**: Admin-controlled redemption approvals
- **1:1 BTC pegging**: All collateral valued equally at 1:1 ratio
- **ERC4626 compliance**: Standard vault interface for DeFi composability
- **Comprehensive testing**: 100% line coverage, 94% branch coverage

## 🏗️ Architecture

```
BtcVaultToken (ERC4626)          BtcVaultStrategy
    │                                │
    ├─ Vault shares                  ├─ Collateral management
    ├─ Deposit/withdraw              ├─ Liquidity management
    └─ Managed withdrawals           └─ Asset registry
```

### Key Components

1. **BtcVaultToken** (`src/token/BtcVaultToken.sol`)
   - Extends `ManagedWithdrawRWA` from FountFi
   - Handles share token issuance and redemption
   - Implements managed withdrawal pattern

2. **BtcVaultStrategy** (`src/strategy/BtcVaultStrategy.sol`)
   - Extends `ReportedStrategy` from FountFi
   - Manages collateral whitelist
   - Controls sovaBTC liquidity pool
   - Processes deposits and withdrawals

## 🚦 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Node.js v18+ (for frontend)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/fountfi-sovabtc.git
cd fountfi-sovabtc

# Install dependencies
forge install

# Install frontend dependencies
cd frontend && npm install
cd ..
```

### Build & Test

```bash
# Build contracts
forge build

# Run all tests (481 tests)
forge test

# Run with gas report
forge test --gas-report

# Check coverage (100% line coverage achieved)
forge coverage

# Run specific test suite
forge test --match-contract BtcVaultRefactorTest -vv
```

### Local Development

```bash
# Start frontend development server
npm run dev

# Frontend will be available at http://localhost:3000
```

## 💻 Frontend Interface

The vault system includes a comprehensive web interface for:

- **Depositing collateral**: Support for all whitelisted BTC variants
- **Requesting redemptions**: Submit withdrawal requests for admin approval
- **Viewing vault stats**: Real-time TVL, share price, and liquidity data
- **Admin panel**: Collateral management and withdrawal approvals

### Frontend Setup

1. Configure wallet connection (MetaMask, WalletConnect, etc.)
2. Switch to Base Sepolia network
3. Ensure you have test ETH for gas fees

## 🔧 Smart Contract Usage

### For Users

#### Depositing Collateral

```solidity
// 1. Approve collateral spending
IERC20(wbtcAddress).approve(strategyAddress, amount);

// 2. Deposit collateral for vault shares
IBtcVaultStrategy(strategyAddress).depositCollateral(
    wbtcAddress,  // collateral token
    amount,       // amount to deposit
    receiver      // address to receive shares
);
```

#### Requesting Redemption

```solidity
// Request redemption (requires admin approval)
IBtcVaultShareToken(tokenAddress).requestRedeem(
    shares,    // amount of shares to redeem
    receiver,  // address to receive sovaBTC
    owner      // owner of the shares
);
```

### For Administrators

#### Managing Collateral

```solidity
// Add new collateral type
strategy.addSupportedCollateral(tokenAddress, ratio);

// Remove collateral type
strategy.removeSupportedCollateral(tokenAddress);

// Check if collateral is supported
bool supported = strategy.isSupportedCollateral(tokenAddress);
```

#### Managing Liquidity

```solidity
// Add sovaBTC liquidity for withdrawals
strategy.addLiquidity(amount);

// Remove excess liquidity
strategy.removeLiquidity(amount);

// Check available liquidity
uint256 available = strategy.availableLiquidity();
```

#### Processing Withdrawals

```solidity
// Approve pending withdrawal request
strategy.approveWithdrawal(requestId);

// Reject withdrawal request
strategy.rejectWithdrawal(requestId);

// Batch process multiple withdrawals
strategy.batchApproveWithdrawals(requestIds);
```

## 📝 Testing Scripts

### Add Test Liquidity

```bash
# Mint test tokens
forge script script/MintTestTokens.s.sol --rpc-url base-sepolia --broadcast

# Add liquidity to strategy
forge script script/AddLiquidity.s.sol --rpc-url base-sepolia --broadcast
```

### Verify Deployment

```bash
# Run verification script
forge script script/verify/VerifyBtcVault.s.sol --rpc-url base-sepolia

# Check via cast commands
cast call 0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8 "availableLiquidity()" --rpc-url base-sepolia
```

## 🧪 Test Coverage

```
| File                        | % Lines | % Statements | % Branches | % Funcs |
|-----------------------------|---------|--------------|------------|---------|
| src/strategy/BtcVaultStrategy.sol | 100.00  | 100.00      | 86.36      | 100.00  |
| src/token/BtcVaultToken.sol       | 100.00  | 100.00      | 75.00      | 100.00  |
| Overall                           | 100.00  | 99.26       | 94.03      | 98.44   |
```

## 🔐 Security Features

- **Role-based access control**: Via FountFi's RoleManager
- **Managed withdrawals**: Admin approval required for redemptions
- **Collateral validation**: Only whitelisted tokens accepted
- **Liquidity checks**: Ensures sufficient sovaBTC for withdrawals
- **Comprehensive testing**: 481 tests with near-perfect coverage

## 📚 Documentation

- [Integration Guide](docs/INTEGRATION_GUIDE.md) - Technical integration details
- [User Guide](docs/USER_GUIDE.md) - End-user documentation
- [Admin Guide](docs/ADMIN_GUIDE.md) - Administrator operations
- [Assessment Report](ASSESSMENT_REPORT_REFACTOR.md) - Detailed refactor analysis

## 🛠️ Development Workflow

### Deployment

```bash
# Deploy to testnet
forge script script/deploy/DeployBtcVault.s.sol --rpc-url base-sepolia --broadcast

# Verify contracts
forge verify-contract <address> <contract> --chain-id 84532
```

### Environment Variables

Create a `.env` file:

```bash
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
BASE_SEPOLIA_RPC=https://sepolia.base.org
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built on the [FountFi Protocol](https://github.com/fountfi/protocol)
- Audited by [Omniscia](https://omniscia.io)
- Powered by [Foundry](https://book.getfoundry.sh/)

## 📞 Support

For questions and support:
- Open an issue on GitHub
- Contact the development team

## ⚠️ Disclaimer

This is experimental software deployed on testnet. Use at your own risk. Always verify contract addresses and transactions before interacting with the protocol.