# Sova Prime BTC

A sophisticated multi-collateral Bitcoin vault system built on ERC4626 standards. Sova Prime BTC enables users to deposit various forms of wrapped Bitcoin (WBTC, cbBTC, sovaBTC) and receive **spBTC** vault shares representing their ownership stake in the multi-collateral pool.

## 🚀 Live Mainnet Deployments

### Ethereum Mainnet

| Contract | Address | Explorer |
|----------|---------|----------|
| **BtcVaultStrategy** | `0x2442c6bd31b2E9bfaEF7d63C13e062CAE002a0cd` | [View on Etherscan](https://etherscan.io/address/0x2442c6bd31b2E9bfaEF7d63C13e062CAE002a0cd) |
| **spBTC Token** | `0x37b91af8cfB6858416550a4a301d0EBDa70bdE52` | [View on Etherscan](https://etherscan.io/address/0x37b91af8cfB6858416550a4a301d0EBDa70bdE52) |
| **PriceOracleReporter** | `0x61e34959504168b94eBF094714F66DDF2008D853` | [View on Etherscan](https://etherscan.io/address/0x61e34959504168b94eBF094714F66DDF2008D853) |
| **sovaBTC** | `0xA11e418F06818E8f2E5af10c1a329088CF9b3BB4` | [View on Etherscan](https://etherscan.io/address/0xA11e418F06818E8f2E5af10c1a329088CF9b3BB4) |
| **RoleManager** | `0xD1880cE56803336f6D75D6611e1A50C37CEC6919` | [View on Etherscan](https://etherscan.io/address/0xD1880cE56803336f6D75D6611e1A50C37CEC6919) |

#### Supported Collateral (Ethereum)

| Token | Address | Decimals |
|-------|---------|----------|
| **WBTC** | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 |
| **cbBTC** | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | 8 |
| **sovaBTC** | `0xA11e418F06818E8f2E5af10c1a329088CF9b3BB4` | 8 |

---

### Base Mainnet

| Contract | Address | Explorer |
|----------|---------|----------|
| **BtcVaultStrategy** | `0x47701501B5245dd232C00DDe291f37cF50b0dDfa` | [View on BaseScan](https://basescan.org/address/0x47701501B5245dd232C00DDe291f37cF50b0dDfa) |
| **spBTC Token** | `0x831cc851278e770bA69B856a8b6166abFF365DFF` | [View on BaseScan](https://basescan.org/address/0x831cc851278e770bA69B856a8b6166abFF365DFF) |
| **PriceOracleReporter** | `0xA11e418F06818E8f2E5af10c1a329088CF9b3BB4` | [View on BaseScan](https://basescan.org/address/0xA11e418F06818E8f2E5af10c1a329088CF9b3BB4) |
| **sovaBTC** | `0x528D47215fbFB355371F21CD9099cA859B03d500` | [View on BaseScan](https://basescan.org/address/0x528D47215fbFB355371F21CD9099cA859B03d500) |
| **RoleManager** | `0xE9d77b16A54C95664FD835a03572019F4800bd36` | [View on BaseScan](https://basescan.org/address/0xE9d77b16A54C95664FD835a03572019F4800bd36) |

#### Supported Collateral (Base)

| Token | Address | Decimals |
|-------|---------|----------|
| **WBTC** | `0x0555E30da8f98308EdB960aa94C0Db47230d2B9c` | 8 |
| **cbBTC** | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | 8 |
| **sovaBTC** | `0x528D47215fbFB355371F21CD9099cA859B03d500` | 8 |

---

## 📊 System Overview

Sova Prime BTC provides:

- **Multi-collateral deposits**: Accept WBTC, cbBTC, and sovaBTC
- **Unified redemptions**: All withdrawals processed in sovaBTC
- **Managed withdrawals**: EIP-712 signature-based redemption approvals
- **NAV-aware pricing**: Oracle-based share pricing with gradual transitions
- **ERC4626 compliance**: Standard vault interface for DeFi composability
- **Cross-chain deployment**: Available on Ethereum and Base

## 🏗️ Architecture

```
BtcVaultToken (ERC4626)          BtcVaultStrategy
    │                                │
    ├─ spBTC vault shares            ├─ Multi-collateral management
    ├─ Deposit/withdraw              ├─ Liquidity pool management
    ├─ Managed withdrawals           ├─ NAV-based pricing
    └─ EIP-712 signatures            └─ Collateral registry
                                     │
                                     └─ PriceOracleReporter
                                        ├─ NAV updates
                                        └─ Gradual price transitions
```

### Key Components

1. **BtcVaultToken** (`src/token/BtcVaultToken.sol`)
   - ERC4626 vault token (spBTC)
   - Multi-collateral deposit support
   - Managed withdrawal pattern with EIP-712 signatures
   - 18 decimal precision for shares

2. **BtcVaultStrategy** (`src/strategy/BtcVaultStrategy.sol`)
   - Manages collateral whitelist
   - Controls sovaBTC liquidity pool for redemptions
   - Processes deposits and withdrawals
   - Integrates with PriceOracleReporter for NAV

3. **PriceOracleReporter** (`src/reporter/PriceOracleReporter.sol`)
   - Reports Net Asset Value (NAV) per share
   - Gradual price transitions to prevent arbitrage
   - Configurable update permissions
   - Max deviation controls (1% per 24 hours default)

4. **sovaBTC** (`src/token/SovaBTCv1.sol`)
   - Upgradeable ERC20 token (UUPS pattern)
   - Primary liquidity/redemption asset
   - 8 decimal precision

## 🚦 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/SovaNetwork/sovavault.git
cd sovavault

# Install dependencies
forge install
```

### Build & Test

```bash
# Build contracts
forge build

# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Check coverage
forge coverage

# Run specific test suite
forge test --match-contract BtcVaultStrategyTest -vv
```

## 💻 Smart Contract Usage

### For Users

#### Depositing Collateral

```solidity
// 1. Approve collateral spending
IERC20(wbtcAddress).approve(tokenAddress, amount);

// 2. Deposit collateral for spBTC vault shares
IBtcVaultToken(tokenAddress).depositCollateral(
    wbtcAddress,  // collateral token (WBTC, cbBTC, or sovaBTC)
    amount,       // amount to deposit (8 decimals)
    receiver      // address to receive spBTC shares
);
```

#### Checking Share Value

```solidity
// Preview deposit
uint256 shares = token.previewDepositCollateral(wbtcAddress, amount);

// Convert shares to assets
uint256 assets = token.convertToAssets(shares);

// Get current NAV
uint256 nav = reporter.getCurrentPrice();
```

#### Requesting Redemption

Withdrawals require off-chain signature from the strategy manager:

```solidity
// User signs withdrawal request (EIP-712)
// Manager approves and signs
// User submits both signatures to redeem
token.redeem(withdrawalRequest, userSignature);
```

### For Administrators

#### Managing Collateral

```solidity
// Add new collateral type
strategy.addCollateral(tokenAddress);

// Remove collateral type
strategy.removeCollateral(tokenAddress);

// Check if collateral is supported
bool supported = strategy.isSupportedAsset(tokenAddress);

// View all supported collaterals
address[] memory collaterals = strategy.getSupportedCollaterals();
```

#### Managing Liquidity

```solidity
// Add sovaBTC liquidity for redemptions
strategy.addLiquidity(amount);

// Remove excess liquidity
strategy.removeLiquidity(amount, recipient);

// Check available liquidity
uint256 available = strategy.availableLiquidity();

// View total collateral
uint256 total = strategy.totalCollateralAssets();
```

#### Updating NAV

```solidity
// Update price oracle (authorized updater only)
reporter.update(
    newPricePerShare,  // 18 decimals (e.g., 1.03e18 = 1.03)
    "Daily NAV Update"
);

// Force complete transition (owner only, emergency)
reporter.forceCompleteTransition();

// Check transition progress
uint256 progress = reporter.getTransitionProgress(); // 0-10000 (basis points)
```

## 🔧 Deployment

### Deploy to Mainnet

```bash
# 1. Set environment variables
export PRIVATE_KEY="your_private_key"
export ETH_RPC_URL="your_ethereum_rpc_url"
export ETHERSCAN_API_KEY="your_etherscan_api_key"

# 2. Deploy RoleManager
forge create src/auth/RoleManager.sol:RoleManager \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# 3. Deploy sovaBTC
NETWORK=ethereumMainnet forge script script/deploy/DeploySovaBTCv1.s.sol:DeploySovaBTCv1 \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# 4. Update deployment.config.json with addresses

# 5. Deploy BTC Vault
NETWORK=ethereumMainnet forge script script/deploy/DeployBtcVault.s.sol:DeployBtcVault \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

See [ETHEREUM_DEPLOYMENT_COMMANDS.md](ETHEREUM_DEPLOYMENT_COMMANDS.md) for detailed deployment instructions.

## 🧪 Test Coverage

```
| File                              | % Lines | % Statements | % Branches | % Funcs |
|-----------------------------------|---------|--------------|------------|---------|
| src/strategy/BtcVaultStrategy.sol | 100.00  | 100.00       | 86.36      | 100.00  |
| src/token/BtcVaultToken.sol       | 100.00  | 100.00       | 75.00      | 100.00  |
| src/reporter/PriceOracleReporter.sol | 98.50 | 98.75       | 92.31      | 100.00  |
| Overall                           | 99.12   | 99.26        | 88.15      | 99.44   |
```

## 🔐 Security Features

- **Role-based access control**: Hierarchical permission system via RoleManager
- **Managed withdrawals**: EIP-712 signature verification for redemptions
- **Collateral validation**: Only whitelisted tokens accepted
- **NAV protection**: Gradual price transitions prevent flash loan attacks
- **Liquidity checks**: Ensures sufficient sovaBTC for withdrawals
- **Comprehensive testing**: Near-perfect test coverage
- **Upgradeable design**: UUPS proxy pattern for sovaBTC token

## 📚 Key Features

### Multi-Collateral Support
Deposit any supported BTC-pegged asset (WBTC, cbBTC, sovaBTC) and receive spBTC shares.

### NAV-Based Pricing
Share prices reflect the Net Asset Value of the underlying portfolio, updated via oracle.

### Managed Withdrawals
Redemptions require manager approval via EIP-712 signatures, enabling compliance and risk management.

### Gradual NAV Transitions
Price updates transition gradually (max 1% per 24 hours by default) to prevent arbitrage and maintain stability.

### Cross-Chain Deployment
Identical contracts deployed on both Ethereum and Base for maximum accessibility.

## 🛠️ Configuration

### Optimizer Settings

The contracts use **30 optimizer runs** to prioritize deployment size over runtime gas costs:

```toml
optimizer = true
optimizer_runs = 30
```

### Environment Variables

Create a `.env` file:

```bash
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC_URL=https://mainnet.base.org
```

## 📖 Documentation

- [Ethereum Deployment Guide](ETHEREUM_MAINNET_DEPLOYMENT.md) - Mainnet deployment instructions
- [Quick Deploy Commands](ETHEREUM_DEPLOYMENT_COMMANDS.md) - Copy-paste deployment commands
- [Integration Guide](docs/INTEGRATION_GUIDE.md) - Technical integration details
- [Project Instructions](CLAUDE.md) - Development guidelines

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the BUSL-1.1 License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Foundry](https://book.getfoundry.sh/)
- Uses [Solady](https://github.com/Vectorized/solady) for gas-optimized libraries
- Implements [OpenZeppelin](https://openzeppelin.com/) upgradeable contracts

## 📞 Support

For questions and support:
- Open an issue on GitHub
- Visit [sova.network](https://sova.network)

## ⚠️ Disclaimer

This software is provided "as is" without warranty of any kind. Users should conduct their own research and audit before interacting with smart contracts. Always verify contract addresses match the official deployments listed above.
