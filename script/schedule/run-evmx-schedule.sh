#!/bin/bash

# Build contracts

if ! forge build; then
    echo "Error: forge build failed. Check your contract code."
    exit 1
fi

# Check if .env exists and load it
if [ -f ".env" ]; then
    echo "Loading environment variables from .env"
    source .env
else
    echo "Error: .env file not found!"
    exit 1
fi

# Ensure required variables are set
if [ -z "$EVMX_RPC" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESS_RESOLVER" ]; then
    echo "Error: EVMX_RPC, PRIVATE_KEY, or ADDRESS_RESOLVER is not set."
    exit 1
fi

# Constants
ARB_SEP_CHAIN_ID=421614
ETH_ADDRESS=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
DEPLOY_FEES_AMOUNT=500000000000000  # 0.0005 ETH in wei
FEES_AMOUNT="1000000000000000"  # 0.001 ETH in wei
GAS_BUFFER="100000000"  # 0.1 Gwei in wei
GAS_LIMIT="3000000"  # Gas limit estimate
EVMX_VERIFIER_URL="https://evmx.cloud.blockscout.com/api"

SENDER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
if [ -z "$SENDER_ADDRESS" ]; then
    echo "Error: Failed to derive sender address."
    exit 1
fi

echo "Sender address: $SENDER_ADDRESS"

# Fetch sender balance
BALANCE_WEI=$(cast balance "$SENDER_ADDRESS" --rpc-url "$ARBITRUM_SEPOLIA_RPC")
if [ -z "$BALANCE_WEI" ]; then
    echo "Error: Failed to fetch sender balance."
    exit 1
fi

echo "Sender balance in wei: $BALANCE_WEI"

# ---------------------- DEPLOY CONTRACT ----------------------
DEPLOY_OUTPUT=$(forge create src/schedule/ScheduleAppGateway.sol:ScheduleAppGateway \
    --rpc-url "$EVMX_RPC" \
    --private-key "$PRIVATE_KEY" \
    --legacy \
    --broadcast \
    --gas-price 0 \
    --verify \
    --verifier-url "$EVMX_VERIFIER_URL" \
    --verifier blockscout \
    --constructor-args "$ADDRESS_RESOLVER" "($ARB_SEP_CHAIN_ID, $ETH_ADDRESS, $DEPLOY_FEES_AMOUNT)")

# Extract the deployed address
APP_GATEWAY=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

# Check if extraction was successful
if [ -z "$APP_GATEWAY" ]; then
    echo "Error: Failed to extract deployed address."
    exit 1
fi

echo "AppGateway deployed at: $APP_GATEWAY"

# ---------------------- DEPOSIT FUNDS ----------------------
cast send "$ARBITRUM_FEES_PLUG" \
    --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
    --private-key "$PRIVATE_KEY" \
    --value "$FEES_AMOUNT" \
    "deposit(address,address,uint256)" "$ETH_ADDRESS" "$APP_GATEWAY" "$FEES_AMOUNT"

if [ $? -eq 0 ]; then
    echo "Fees deposited successfully!"
else
    echo "Error: Failed to deposit fees."
    exit 1
fi

# ---------------------- WITHDRAW FUNDS ----------------------

# Get available fees from EVMX chain
AVAILABLE_FEES_RAW=$(cast call "$FEES_MANAGER" \
    "getAvailableFees(uint32,address,address)(uint256)" \
    "$ARB_SEP_CHAIN_ID" "$APP_GATEWAY" "$ETH_ADDRESS" \
    --rpc-url "$EVMX_RPC")

AVAILABLE_FEES=$(echo "$AVAILABLE_FEES_RAW" | awk '{print $1}')
echo "Available fees: $AVAILABLE_FEES"

# Ensure it's a valid integer before proceeding
if ! [[ "$AVAILABLE_FEES" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid available fees value: $AVAILABLE_FEES"
    exit 1
fi

# Check if there are funds to withdraw
if [ "$AVAILABLE_FEES" -gt 0 ]; then
    # Fetch gas price on Arbitrum Sepolia
    ARBITRUM_GAS_PRICE=$(cast base-fee --rpc-url "$ARBITRUM_SEPOLIA_RPC")

    # Add buffer to gas price
    GAS_PRICE=$((ARBITRUM_GAS_PRICE + GAS_BUFFER))
    ESTIMATED_GAS_COST=$((GAS_LIMIT * GAS_PRICE))

    echo "Arbitrum gas price (wei): $ARBITRUM_GAS_PRICE"
    echo "Gas limit: $GAS_LIMIT"
    echo "Estimated gas cost: $ESTIMATED_GAS_COST"

    # Calculate withdrawal amount
    AMOUNT_TO_WITHDRAW=0
    if [ "$AVAILABLE_FEES" -gt "$ESTIMATED_GAS_COST" ]; then
        AMOUNT_TO_WITHDRAW=$((AVAILABLE_FEES - ESTIMATED_GAS_COST))
    fi

    if [ "$AMOUNT_TO_WITHDRAW" -gt 0 ]; then
        echo "Withdrawing amount: $AMOUNT_TO_WITHDRAW"

        # Withdraw funds from the contract
        cast send "$APP_GATEWAY" \
            --rpc-url "$EVMX_RPC" \
            --private-key "$PRIVATE_KEY" \
            --legacy \
            --gas-price 0 \
            "withdrawFeeTokens(uint32,address,uint256,address)" \
            "$ARB_SEP_CHAIN_ID" "$ETH_ADDRESS" "$AMOUNT_TO_WITHDRAW" "$SENDER_ADDRESS"

        if [ $? -eq 0 ]; then
            echo "Fees withdrawn successfully!"
        else
            echo "Error: Failed to withdraw fees."
            exit 1
        fi

        # Check final balance after withdrawal
        FINAL_BALANCE=$(cast balance "$SENDER_ADDRESS" --rpc-url "$ARBITRUM_SEPOLIA_RPC")
        echo "Final sender balance: $FINAL_BALANCE"
    else
        echo "Available fees are less than estimated gas cost. Skipping withdrawal."
    fi
else
    echo "No available fees to withdraw."
fi

