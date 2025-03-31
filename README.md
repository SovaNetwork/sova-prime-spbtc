# FountFi - RWA Tokenization Protocol

FountFi is a protocol for tokenizing Real World Assets (RWA) on-chain, providing a secure and compliant bridge between traditional finance and DeFi.

## Overview

The protocol offers:

- **Share-based accounting**: Each token represents a share in the underlying real-world fund
- **NAV Integration**: Token value is connected to the underlying asset's Net Asset Value
- **Compliance layer**: Built-in KYC/AML and transfer restriction capabilities
- **Modular architecture**: Flexible and upgradeable components

## Key Components

1. **tRWA Token**: The main token contract representing shares in real-world assets
2. **NavOracle**: Updates the NAV (Net Asset Value) per share
3. **ComplianceModule**: Handles KYC/AML requirements and transfer restrictions
4. **tRWAFactory**: Creates and deploys new tokenized RWA assets

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Installation

```bash
git clone https://github.com/yourusername/fountfi.git
cd fountfi
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/SimpleRWADeploy.s.sol:SimpleRWADeployScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

## License

MIT License