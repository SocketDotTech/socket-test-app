#!/bin/bash

# ANSI color codes
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Progress Bar Function
progress_bar() {
    local duration=$1
    local width=50
    local interval=$(echo "scale=2; $duration / $width" | bc)

    for ((i=0; i<=width; i++)); do
        printf "\r${CYAN}Waiting 5 sec: [%-${width}s] %d%%${NC}" $(printf "#%.0s" $(seq 1 $i)) $((i*2))
        sleep $interval
    done
    printf "\n"
}

# Function to validate environment and build contracts
prepare_deployment() {
    echo -e "${CYAN}Building contracts${NC}"
    if ! forge build; then
        echo -e "${RED}Error: forge build failed. Check your contract code.${NC}"
        exit 1
    fi

    # Check if .env exists and load it
    if [ -f ".env" ]; then
        echo -e "${CYAN}Loading environment variables from .env${NC}"
        source .env
    else
        echo -e "${RED}Error: .env file not found!${NC}"
        exit 1
    fi

    # Ensure required variables are set
    if [ -z "$EVMX_RPC" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESS_RESOLVER" ]; then
        echo -e "${RED}Error: EVMX_RPC, PRIVATE_KEY, or ADDRESS_RESOLVER is not set.${NC}"
        exit 1
    fi
}

# Function to deploy contract and return block hash
deploy_contract() {
    local DEPLOY_OUTPUT=$(forge create src/schedule/ScheduleAppGateway.sol:ScheduleAppGateway \
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
    local APP_GATEWAY=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

    # Check if extraction was successful
    if [ -z "$APP_GATEWAY" ]; then
        echo -e "${RED}Error: Failed to extract deployed address.${NC}"
        exit 1
    fi

    # Extract and return block hash
    echo "$APP_GATEWAY"  # Return address for subsequent functions
}

# Function to deposit funds and return block hash
deposit_funds() {
    local APP_GATEWAY="$1"

    # Deposit funds
    local DEPOSIT_OUTPUT=$(cast send "$ARBITRUM_FEES_PLUG" \
        --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
        --private-key "$PRIVATE_KEY" \
        --value "$FEES_AMOUNT" \
        "deposit(address,address,uint256)" "$ETH_ADDRESS" "$APP_GATEWAY" "$FEES_AMOUNT")

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deposit fees.${NC}"
        exit 1
    fi

    # Extract and return block hash
    local DEPOSIT_BLOCK_HASH=$(echo "$DEPOSIT_OUTPUT" | grep "blockHash" | head -n 1 | awk '{print $2}')
    echo "Deposit Block Hash: https://arbitrum-sepolia.blockscout.com/tx/$DEPOSIT_BLOCK_HASH"
}

# Function to withdraw funds and return block hash
withdraw_funds() {
    local APP_GATEWAY="$1"
    local SENDER_ADDRESS="$2"

    # Get available fees from EVMX chain
    local AVAILABLE_FEES_RAW=$(cast call "$FEES_MANAGER" \
        "getAvailableFees(uint32,address,address)(uint256)" \
        "$ARB_SEP_CHAIN_ID" "$APP_GATEWAY" "$ETH_ADDRESS" \
        --rpc-url "$EVMX_RPC")

    local AVAILABLE_FEES=$(echo "$AVAILABLE_FEES_RAW" | awk '{print $1}')

    # Ensure it's a valid integer before proceeding
    if ! [[ "$AVAILABLE_FEES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid available fees value: $AVAILABLE_FEES${NC}"
        exit 1
    fi

    echo "Available Fees: $AVAILABLE_FEES wei"

    # Check if there are funds to withdraw
    if [ "$AVAILABLE_FEES" -gt 0 ]; then
        # Fetch gas price on Arbitrum Sepolia
        local ARBITRUM_GAS_PRICE=$(cast base-fee --rpc-url "$ARBITRUM_SEPOLIA_RPC")

        # Add buffer to gas price
        local GAS_PRICE=$((ARBITRUM_GAS_PRICE + GAS_BUFFER))
        local ESTIMATED_GAS_COST=$((GAS_LIMIT * GAS_PRICE))

        # Calculate withdrawal amount
        local AMOUNT_TO_WITHDRAW=0
        if [ "$AVAILABLE_FEES" -gt "$ESTIMATED_GAS_COST" ]; then
            AMOUNT_TO_WITHDRAW=$((AVAILABLE_FEES - ESTIMATED_GAS_COST))
        fi

        if [ "$AMOUNT_TO_WITHDRAW" -gt 0 ]; then
            # Withdraw funds from the contract
            local WITHDRAW_OUTPUT=$(cast send "$APP_GATEWAY" \
                --rpc-url "$EVMX_RPC" \
                --private-key "$PRIVATE_KEY" \
                --legacy \
                --gas-price 0 \
                "withdrawFeeTokens(uint32,address,uint256,address)" \
                "$ARB_SEP_CHAIN_ID" "$ETH_ADDRESS" "$AMOUNT_TO_WITHDRAW" "$SENDER_ADDRESS")

            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to withdraw fees.${NC}"
                exit 1
            fi

            # Extract and return block hash
            local BLOCK_HASH=$(echo "$WITHDRAW_OUTPUT" | grep "blockHash" | head -n 1 | awk '{print $2}')
            echo "Withdraw Block Hash: https://evmx.cloud.blockscout.com/tx/$BLOCK_HASH"
        else
            echo "No funds available for withdrawal after gas cost estimation."
            exit 0
        fi
    else
        echo "No available fees to withdraw."
        exit 0
    fi
}

# Main execution
main() {
    # Constants
    ARB_SEP_CHAIN_ID=421614
    ETH_ADDRESS=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    DEPLOY_FEES_AMOUNT=500000000000000  # 0.0005 ETH in wei
    FEES_AMOUNT="1000000000000000"  # 0.001 ETH in wei
    GAS_BUFFER="100000000"  # 0.1 Gwei in wei
    GAS_LIMIT="3000000"  # Gas limit estimate
    EVMX_VERIFIER_URL="https://evmx.cloud.blockscout.com/api"

    # Prepare deployment environment
    prepare_deployment

    # Get sender address
    SENDER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
    if [ -z "$SENDER_ADDRESS" ]; then
        echo -e "${RED}Error: Failed to derive sender address.${NC}"
        exit 1
    fi

    # Add 2>/dev/null to suppress warnings
    exec 2>/dev/null

    echo -e "${CYAN}Deploying AppGateway contract${NC}"
    #APP_GATEWAY=$(deploy_contract)
    echo "AppGateway: https://evmx.cloud.blockscout.com/address/$APP_GATEWAY"
    progress_bar 5

    echo -e "${CYAN}Depositing funds${NC}"
    deposit_funds "$APP_GATEWAY"
    progress_bar 5

    echo -e "${CYAN}Withdrawing funds${NC}"
    withdraw_funds "$APP_GATEWAY" "$SENDER_ADDRESS"
}

# Run the main function
main
