#!/bin/bash

# Base Sepolia Contract Verification Script
# This script verifies all deployed contracts on Base Sepolia

set -e

echo "======================================"
echo "Base Sepolia Contract Verification"
echo "======================================"
echo ""

# Set API key (can be overridden by environment variable)
BASESCAN_KEY=${BASESCAN_KEY:-"KI5PMY8D813UGVZS7MEFMW7BW4AU8A14DV"}

# Contract addresses
ROLE_MANAGER="0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72"
REGISTRY="0x15a9983784617aa8892b2677bbaEc23539482B65"
STRATEGY="0x740907524EbD6A481a81cE76B5115A4cDDb80099"
VAULT="0x73E27097221d4d9D5893a83350dC7A967b46fab7"
QUEUE="0x22BC73098CE1Ba2CaE5431fb32051cB4fc0F9C52"
ORACLE="0xDB4479A2360E118CCbD99B88e82522813BDE48f5"
SOVABTC="0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9"

echo "Using API Key: ${BASESCAN_KEY:0:6}..."
echo ""

# Function to verify a contract
verify_contract() {
    local name=$1
    local address=$2
    local contract_path=$3
    local constructor_args=$4
    
    echo "Verifying $name at $address..."
    
    if [ -z "$constructor_args" ]; then
        forge verify-contract $address $contract_path \
            --chain-id 84532 \
            --etherscan-api-key $BASESCAN_KEY \
            --watch || echo "Failed to verify $name (may already be verified)"
    else
        forge verify-contract $address $contract_path \
            --chain-id 84532 \
            --etherscan-api-key $BASESCAN_KEY \
            --constructor-args $constructor_args \
            --watch || echo "Failed to verify $name (may already be verified)"
    fi
    
    echo ""
    sleep 2 # Rate limiting
}

# Verify RoleManager
echo "1. Verifying RoleManager..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" $ROLE_MANAGER)
verify_contract "RoleManager" $ROLE_MANAGER "src/RoleManager.sol:RoleManager" $CONSTRUCTOR_ARGS

# Verify Registry
echo "2. Verifying MultiCollateralRegistry..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" $ROLE_MANAGER)
verify_contract "MultiCollateralRegistry" $REGISTRY "src/strategies/MultiCollateralRegistry.sol:MultiCollateralRegistry" $CONSTRUCTOR_ARGS

# Verify Strategy
echo "3. Verifying MultiCollateralStrategy..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address)" $ROLE_MANAGER $REGISTRY)
verify_contract "MultiCollateralStrategy" $STRATEGY "src/strategies/MultiCollateralStrategy.sol:MultiCollateralStrategy" $CONSTRUCTOR_ARGS

# Verify Vault
echo "4. Verifying MultiBTCVault..."
# Complex constructor, might need manual verification
verify_contract "MultiBTCVault" $VAULT "src/vaults/MultiBTCVault.sol:MultiBTCVault" ""

# Verify Queue
echo "5. Verifying ManagedRedemptionQueue..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,address)" $ROLE_MANAGER $VAULT $SOVABTC)
verify_contract "ManagedRedemptionQueue" $QUEUE "src/vaults/ManagedRedemptionQueue.sol:ManagedRedemptionQueue" $CONSTRUCTOR_ARGS

# Verify Oracle
echo "6. Verifying PriceOracleReporter..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" $ROLE_MANAGER)
verify_contract "PriceOracleReporter" $ORACLE "src/oracles/PriceOracleReporter.sol:PriceOracleReporter" $CONSTRUCTOR_ARGS

echo "======================================"
echo "Verification Summary"
echo "======================================"
echo ""
echo "Check verification status at:"
echo ""
echo "RoleManager: https://sepolia.basescan.org/address/$ROLE_MANAGER#code"
echo "Registry: https://sepolia.basescan.org/address/$REGISTRY#code"
echo "Strategy: https://sepolia.basescan.org/address/$STRATEGY#code"
echo "Vault: https://sepolia.basescan.org/address/$VAULT#code"
echo "Queue: https://sepolia.basescan.org/address/$QUEUE#code"
echo "Oracle: https://sepolia.basescan.org/address/$ORACLE#code"
echo ""
echo "Verification process complete!"
echo ""
echo "Note: Some contracts may fail if already verified."
echo "Check the Basescan links above to confirm status."