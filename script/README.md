# Multi-Collateral BTC Vault Deployment Guide

## Overview
This directory contains deployment and admin scripts for the Multi-Collateral BTC Vault system.

## Directory Structure
```
script/
├── deploy/              # Main deployment scripts
│   ├── 01_DeployCore.s.sol
│   ├── 02_DeployStrategy.s.sol
│   ├── 03_DeployVault.s.sol
│   ├── 04_DeployQueue.s.sol
│   ├── 05_DeployReporter.s.sol
│   └── 06_Configure.s.sol
├── admin/               # Admin operation scripts
│   ├── UpdatePriceOracle.s.sol
│   ├── ProcessRedemptions.s.sol
│   ├── EmergencyPause.s.sol
│   └── ManageLiquidity.s.sol
├── helpers/             # Helper contracts and utilities
│   ├── DeploymentConfig.sol
│   ├── DeploymentAddresses.sol
│   └── DeployMockTokens.s.sol
└── DeployAll.s.sol      # Master deployment script
```

## Setup

1. **Copy Environment File**
```bash
cp .env.example .env
```

2. **Configure Environment Variables**
Edit `.env` with your settings:
- `PRIVATE_KEY`: Deployer wallet private key
- `ADMIN_PRIVATE_KEY`: Admin wallet private key
- `RPC_URL_MAINNET`: Mainnet RPC endpoint
- `RPC_URL_SEPOLIA`: Sepolia testnet RPC endpoint
- `ETHERSCAN_API_KEY`: For contract verification
- `PROTOCOL_ADMIN_ADDRESS`: Protocol admin address
- `PRICE_ORACLE_UPDATER`: Price oracle updater address

## Deployment

### Full Deployment (All Contracts)
```bash
# Deploy to local fork
forge script script/DeployAll.s.sol --fork-url $RPC_URL_MAINNET

# Deploy to Sepolia testnet
forge script script/DeployAll.s.sol --rpc-url $RPC_URL_SEPOLIA --broadcast --verify

# Deploy to mainnet
forge script script/DeployAll.s.sol --rpc-url $RPC_URL_MAINNET --broadcast --verify
```

### Individual Contract Deployment
```bash
# Deploy only core contracts
forge script script/deploy/01_DeployCore.s.sol --rpc-url $RPC_URL_SEPOLIA --broadcast

# Deploy strategy
forge script script/deploy/02_DeployStrategy.s.sol --rpc-url $RPC_URL_SEPOLIA --broadcast

# Continue with other contracts...
```

### Deploy Mock Tokens (Testnet Only)
```bash
forge script script/helpers/DeployMockTokens.s.sol --rpc-url $RPC_URL_SEPOLIA --broadcast
```

## Admin Operations

### Update Price Oracle (NAV)
```bash
# Set NEW_PRICE in .env (in 18 decimals)
# Example: 1.05 = 1050000000000000000
NEW_PRICE=1050000000000000000 forge script script/admin/UpdatePriceOracle.s.sol --rpc-url $RPC_URL_MAINNET --broadcast
```

### Process Redemptions
```bash
# Process pending redemptions after 14-day waiting period
forge script script/admin/ProcessRedemptions.s.sol --rpc-url $RPC_URL_MAINNET --broadcast
```

### Emergency Pause/Unpause
```bash
# Pause the system
PAUSE=true forge script script/admin/EmergencyPause.s.sol --rpc-url $RPC_URL_MAINNET --broadcast

# Unpause the system
PAUSE=false forge script script/admin/EmergencyPause.s.sol --rpc-url $RPC_URL_MAINNET --broadcast
```

### Manage Liquidity
```bash
# Add 1 BTC of sovaBTC liquidity
DEPOSIT=true AMOUNT=100000000 forge script script/admin/ManageLiquidity.s.sol --rpc-url $RPC_URL_MAINNET --broadcast

# Remove 0.5 BTC of sovaBTC liquidity
DEPOSIT=false AMOUNT=50000000 forge script script/admin/ManageLiquidity.s.sol --rpc-url $RPC_URL_MAINNET --broadcast
```

## Verification

### Verify Contracts on Etherscan
```bash
# Verify a specific contract
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id 1 --etherscan-api-key $ETHERSCAN_API_KEY

# Example: Verify MultiBTCVault
forge verify-contract 0x123... src/vaults/MultiBTCVault.sol:MultiBTCVault --chain-id 1 --etherscan-api-key $ETHERSCAN_API_KEY
```

## Testing Deployment

### Test on Local Fork
```bash
# 1. Start local fork
anvil --fork-url $RPC_URL_MAINNET

# 2. Deploy contracts
forge script script/DeployAll.s.sol --rpc-url http://localhost:8545 --broadcast

# 3. Run integration tests
forge test --match-contract DeploymentTest --fork-url http://localhost:8545
```

### Test User Flow
```bash
# 1. Deploy mock tokens
forge script script/helpers/DeployMockTokens.s.sol --rpc-url http://localhost:8545 --broadcast

# 2. Approve and deposit WBTC
cast send <WBTC_ADDRESS> "approve(address,uint256)" <VAULT_ADDRESS> 100000000 --rpc-url http://localhost:8545

cast send <VAULT_ADDRESS> "depositCollateral(address,uint256,address)" <WBTC_ADDRESS> 100000000 <USER_ADDRESS> --rpc-url http://localhost:8545

# 3. Queue redemption
cast send <VAULT_ADDRESS> "queueRedemption(uint256)" <SHARES_AMOUNT> --rpc-url http://localhost:8545

# 4. Wait 14 days (or warp time in test)
# 5. Process redemption (admin)
forge script script/admin/ProcessRedemptions.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Post-Deployment Checklist

- [ ] All contracts deployed successfully
- [ ] Contracts verified on Etherscan
- [ ] Admin roles configured correctly
- [ ] Initial collateral tokens registered
- [ ] Conversion rates set properly
- [ ] Price oracle initialized with correct NAV
- [ ] Redemption period set to 14 days
- [ ] Minimum investment set to 0.001 BTC
- [ ] Strategy funded with initial sovaBTC liquidity
- [ ] Test deposit successful
- [ ] Test redemption queue successful
- [ ] Emergency pause tested
- [ ] Admin can update price oracle
- [ ] Admin can process redemptions

## Troubleshooting

### Common Issues

1. **"RoleManager not deployed"**
   - Ensure you run deployment scripts in order (01 → 06)
   - Check that previous deployments succeeded

2. **"Insufficient sovaBTC balance"**
   - Strategy needs sovaBTC liquidity for redemptions
   - Use ManageLiquidity script to add funds

3. **"Price update failed"**
   - Ensure admin has PROTOCOL_ADMIN role
   - Check that reporter address is correct

4. **Gas estimation errors**
   - Increase gas limit in foundry.toml
   - Ensure sufficient ETH in deployer wallet

## Security Considerations

1. **Private Keys**: Never commit private keys to git
2. **Admin Access**: Use multi-sig for admin operations in production
3. **Liquidity**: Ensure sufficient sovaBTC before enabling redemptions
4. **Price Updates**: Implement time delays or multi-sig for NAV updates
5. **Emergency Procedures**: Test pause functionality before mainnet

## Support

For issues or questions:
- Review test files in `test/` for usage examples
- Check integration tests in `test/integration/`
- Refer to main documentation in project root