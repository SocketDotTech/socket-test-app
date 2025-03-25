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

