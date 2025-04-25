#!/bin/bash

# Global constants for verification
RPC_URL="https://rpc.testnet.sova.io"
VERIFIER="blockscout"
VERIFIER_URL="https://explorer.testnet.sova.io/api/"

# Parse command line arguments
DEPLOYMENT_FILE=""

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deployment-file)
            DEPLOYMENT_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Find the latest deployment file
if [ -z "$DEPLOYMENT_FILE" ]; then
    LATEST_DEPLOYMENT=$(find $(pwd)/broadcast -name "run-latest.json" | grep -v "dry-run" | head -1)
else
    LATEST_DEPLOYMENT="$DEPLOYMENT_FILE"
fi

if [ -z "$LATEST_DEPLOYMENT" ]; then
    echo "Error: Could not find latest deployment file"
    exit 1
fi

echo "Using deployment file: $LATEST_DEPLOYMENT"

# Function to verify a contract
verify_contract() {
    local address=$1
    local contract_path=$2
    local contract_name=$3

    echo "Verifying $contract_name at $address..."

    forge verify-contract \
        --rpc-url $RPC_URL \
        --verifier $VERIFIER \
        --verifier-url "$VERIFIER_URL" \
        $address \
        $contract_path:$contract_name

    # Add a small delay between verifications to avoid rate limiting
    sleep 2
}

# Function to find contract file path
find_contract_path() {
    local contract_name=$1
    local result

    # Try to find the contract file in src directory
    result=$(find $(pwd)/src -type f -name "*.sol" -exec grep -l "contract $contract_name" {} \; | head -1)

    if [ -n "$result" ]; then
        # Convert absolute path to relative path from project root
        echo "${result#$(pwd)/}"
        return 0
    fi

    # If we get here, we couldn't find the contract file
    return 1
}

echo "Starting contract verification..."

# Process the deployment file to extract contract information
# Use jq if available, otherwise fallback to grep and awk
if command -v jq &> /dev/null; then
    # First, process all main CREATE transactions
    echo "Processing main contract deployments...\n"
    jq -c '.transactions[] | select(.transactionType == "CREATE")' "$LATEST_DEPLOYMENT" | while read -r tx; do
        contract_name=$(echo "$tx" | jq -r '.contractName')
        contract_address=$(echo "$tx" | jq -r '.contractAddress')

        echo "Found deployed contract: $contract_name at $contract_address"

        # Find the contract's file path
        contract_path=$(find_contract_path "$contract_name")

        if [ -n "$contract_path" ]; then
            echo "Contract file found at: $contract_path"
            verify_contract "$contract_address" "$contract_path" "$contract_name"
        else
            echo "Warning: Could not find file for contract $contract_name. Skipping verification."
        fi
    done

    # Now, process all additionalContracts CREATE transactions
    echo "Processing additional contract deployments...\n"

    # Process each transaction with additionalContracts
    jq -c '.transactions[] | select(.additionalContracts != null and .additionalContracts != [])' "$LATEST_DEPLOYMENT" | while read -r tx; do
        parent_function=$(echo "$tx" | jq -r '.function')

        # Get only the CREATE transactions from additionalContracts array
        create_contracts=$(echo "$tx" | jq -c '.additionalContracts[] | select(.transactionType == "CREATE")')

        # Process each CREATE transaction based on its position
        position=0
        echo "$create_contracts" | while read -r contract_info; do
            address=$(echo "$contract_info" | jq -r '.address')

            # Determine contract name and path based on position and function
            contract_name=""
            contract_path=""

            # If parent function is deployWithController, we can infer contract types by position
            if [[ "$parent_function" == *"deployWithController"* ]]; then
                case $position in
                    0)
                        # First contract in deployWithController is a delegate proxy
                        contract_name="ReportedStrategy"
                        contract_path="src/strategy/ReportedStrategy.sol"
                        ;;
                    1)
                        # Second contract in deployWithController is the token
                        contract_name="tRWA"
                        contract_path="src/token/tRWA.sol"
                        ;;
                    2)
                        # Third contract in deployWithController is the SubscriptionController
                        contract_name="SubscriptionController"
                        contract_path="src/controllers/SubscriptionController.sol"
                        ;;
                    3)
                        # Fourth contract in deployWithController is the SubscriptionControllerRule
                        contract_name="SubscriptionControllerRule"
                        contract_path="src/rules/SubscriptionControllerRule.sol"
                        ;;
                    *)
                        # For other positions, try to infer based on common patterns
                        echo "Unknown position $position in additional contracts array"
                        ;;
                esac
            else
                # For other functions, try to infer based on common patterns
                echo "Non-deployWithController function: $parent_function"

                # Try to infer contract name by searching for implementations
                if [[ "$parent_function" == *"deploy"* ]]; then
                    for name in "SubscriptionManager" "WithdrawalManager" "tRWA" "SubscriptionControllerRule"; do
                        potential_path=$(find_contract_path "$name")
                        if [ -n "$potential_path" ]; then
                            contract_name="$name"
                            contract_path="$potential_path"
                            break
                        fi
                    done
                fi
            fi

            # If we found a contract name and path, verify the contract
            if [ -n "$contract_name" ] && [ -n "$contract_path" ]; then
                echo "Found additional deployed contract: $contract_name at $address (position $position)"
                echo "Contract file found at: $contract_path"
                verify_contract "$address" "$contract_path" "$contract_name"
            else
                echo "Warning: Could not identify contract at $address (position $position). Skipping verification."
            fi

            # Increment position for next iteration
            position=$((position+1))
        done
    done
else
    echo "jq not found, please install it."

    return 1
fi

echo "Contract verification complete!"