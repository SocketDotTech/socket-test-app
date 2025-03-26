#!/bin/bash

# ANSI color codes
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Progress Bar Function
progress_bar() {
    local duration=$1
    local width=50
    local interval
    interval=$(echo "scale=2; $duration / $width" | bc)

    for ((i=0; i<=width; i++)); do
        printf "\r${CYAN}Waiting $duration sec: [%-${width}s] %d%%${NC}" "$(printf "#%.0s" $(seq 1 $i)) $((i*2))"
        sleep "$interval"
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
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error: .env file not found!${NC}"
        exit 1
    fi

    echo -e "${CYAN}Loading environment variables from .env${NC}"
    source .env

    # Constants
    export ARB_SEP_CHAIN_ID=421614
    export ETH_ADDRESS=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    export DEPLOY_FEES_AMOUNT=500000000000000  # 0.0005 ETH in wei
    export FEES_AMOUNT="1000000000000000"  # 0.001 ETH in wei
    export GAS_BUFFER="100000000"  # 0.1 Gwei in wei
    export GAS_LIMIT="3000000"  # Gas limit estimate
    export EVMX_VERIFIER_URL="https://evmx.cloud.blockscout.com/api"

    # Ensure required variables are set
    if [ -z "$EVMX_RPC" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESS_RESOLVER" ]; then
        echo -e "${RED}Error: EVMX_RPC, PRIVATE_KEY, or ADDRESS_RESOLVER is not set.${NC}"
        exit 1
    fi
}

# Function to deploy contract and return block hash
deploy_appgateway() {
    local filefolder=$1
    local filename=$2
    echo -e "${CYAN}Deploying $filename contract${NC}"
    local DEPLOY_OUTPUT
    if ! DEPLOY_OUTPUT=$(forge create src/"$filefolder"/"$filename".sol:"$filename" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --broadcast \
        --gas-price 0 \
        --verify \
        --verifier-url "$EVMX_VERIFIER_URL" \
        --verifier blockscout \
        --constructor-args "$ADDRESS_RESOLVER" "($ARB_SEP_CHAIN_ID, $ETH_ADDRESS, $DEPLOY_FEES_AMOUNT)"); then
        echo -e "${RED}Error: Contract deployment failed.${NC}"
        exit 1
    fi

    # Extract the deployed address
    local APP_GATEWAY_ADDRESS
    APP_GATEWAY_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')

    # Check if extraction was successful
    if [ -z "$APP_GATEWAY_ADDRESS" ]; then
        echo -e "${RED}Error: Failed to extract deployed address.${NC}"
        exit 1
    fi

    # Extract and return block hash
    echo -e "AppGateway: https://evmx.cloud.blockscout.com/address/$APP_GATEWAY_ADDRESS"
    export APP_GATEWAY="$APP_GATEWAY_ADDRESS"
}

# Function to deposit funds and return block hash
deposit_funds() {
    local APP_GATEWAY="$1"
    echo -e "${CYAN}Depositing funds${NC}"

    # Deposit funds
    local DEPOSIT_OUTPUT
    if ! DEPOSIT_OUTPUT=$(cast send "$ARBITRUM_FEES_PLUG" \
        --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
        --private-key "$PRIVATE_KEY" \
        --value "$FEES_AMOUNT" \
        "deposit(address,address,uint256)" "$ETH_ADDRESS" "$APP_GATEWAY" "$FEES_AMOUNT"); then
        echo -e "${RED}Error: Failed to deposit fees.${NC}"
        exit 1
    fi

    # Extract and return block hash
    echo "Deposit Block Hash: https://arbitrum-sepolia.blockscout.com/tx/$(echo "$DEPOSIT_OUTPUT" | grep "blockHash" | head -n 1 | awk '{print $2}')"
}

# Function to withdraw funds and return block hash
withdraw_funds() {
    local APP_GATEWAY="$1"
    local SENDER_ADDRESS="$2"
    echo -e "${CYAN}Withdrawing funds${NC}"

    # Get available fees from EVMX chain
    local AVAILABLE_FEES_RAW
    if ! AVAILABLE_FEES_RAW=$(cast call "$FEES_MANAGER" \
        "getAvailableFees(uint32,address,address)(uint256)" \
        "$ARB_SEP_CHAIN_ID" "$APP_GATEWAY" "$ETH_ADDRESS" \
        --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error: Failed to get available fees.${NC}"
        exit 1
    fi

    local AVAILABLE_FEES
    AVAILABLE_FEES=$(echo "$AVAILABLE_FEES_RAW" | awk '{print $1}')

    # Ensure it's a valid integer before proceeding
    if ! [[ "$AVAILABLE_FEES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid available fees value: $AVAILABLE_FEES${NC}"
        exit 1
    fi

    echo "Available Fees: $AVAILABLE_FEES wei"

    # Check if there are funds to withdraw
    if [ "$AVAILABLE_FEES" -gt 0 ]; then
        # Fetch gas price on Arbitrum Sepolia
        local ARBITRUM_GAS_PRICE
        ARBITRUM_GAS_PRICE=$(cast base-fee --rpc-url "$ARBITRUM_SEPOLIA_RPC")

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
            local WITHDRAW_OUTPUT
            if ! WITHDRAW_OUTPUT=$(cast send "$APP_GATEWAY" \
                --rpc-url "$EVMX_RPC" \
                --private-key "$PRIVATE_KEY" \
                --legacy \
                --gas-price 0 \
                "withdrawFeeTokens(uint32,address,uint256,address)" \
                "$ARB_SEP_CHAIN_ID" "$ETH_ADDRESS" "$AMOUNT_TO_WITHDRAW" "$SENDER_ADDRESS"); then
                echo -e "${RED}Error: Failed to withdraw fees.${NC}"
                exit 1
            fi

            # Extract and return block hash
            echo "Withdraw Block Hash: https://evmx.cloud.blockscout.com/tx/$(echo "$WITHDRAW_OUTPUT" | grep "blockHash" | head -n 1 | awk '{print $2}')"
        else
            echo "No funds available for withdrawal after gas cost estimation."
            exit 0
        fi
    else
        echo "No available fees to withdraw."
        exit 0
    fi
}

# Function to read timeouts from the contract
read_timeouts() {
    echo -e "${CYAN}Reading timeouts from the contract:${NC}"

    export MAX_TIMEOUT=0
    export NUMBER_OF_TIMEOUTS=0

    while true; do
        timeout=""
        if ! timeout=$(cast call "$APP_GATEWAY" "timeoutsInSeconds(uint256)(uint256)" $NUMBER_OF_TIMEOUTS \
            --rpc-url "$EVMX_RPC" \
            2>/dev/null); then
            break
        fi

        if [ -z "$timeout" ]; then
            break
        fi

        echo -e "Timeout $NUMBER_OF_TIMEOUTS: $timeout seconds"
        NUMBER_OF_TIMEOUTS=$((NUMBER_OF_TIMEOUTS+1))

        if [ "$timeout" -gt "$MAX_TIMEOUT" ]; then
            MAX_TIMEOUT=$timeout
        fi
    done
}

# Function to trigger timeouts
trigger_timeouts() {
    echo -e "${CYAN}Triggering timeouts...${NC}"
    if ! cast send "$APP_GATEWAY" "triggerTimeouts()" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0; then
        echo -e "${RED}Error: Failed to trigger timeouts.${NC}"
        exit 1
    fi
}

# Function to listen for TimeoutResolved events
show_timeout_events() {
    echo -e "${CYAN}Fetching TimeoutResolved events...${NC}"

    # Fetch logs
    logs=$(cast logs --rpc-url "$EVMX_RPC" --address "$APP_GATEWAY" "TimeoutResolved(uint256,uint256,uint256)")

    # Count occurrences
    event_count=$(echo "$logs" | grep -c "blockHash")

    echo -e "${GREEN}Total TimeoutResolved events: $event_count${NC}"

    if [ "$event_count" -ne "$NUMBER_OF_TIMEOUTS" ]; then
        echo -e "${RED}Warning:${NC} Expected $NUMBER_OF_TIMEOUTS timeouts but found $event_count."
    fi

    # Decode and display event data
    echo "$logs" | grep -E "data:" | while read -r line; do
        data=$(echo "$line" | awk '{print $2}')

        # Extract values from data
        index="0x${data:2:64}"
        creation_timestamp="0x${data:66:64}"
        execution_timestamp="0x${data:130:64}"

        # Convert from hex to decimal
        index=$(cast to-dec "$index")
        creation_timestamp=$(cast to-dec "$creation_timestamp")
        execution_timestamp=$(cast to-dec "$execution_timestamp")

        echo -e "${GREEN}Timeout Resolved:${NC}"
        echo -e "  Index: $index"
        echo -e "  Created at: $creation_timestamp"
        echo -e "  Executed at: $execution_timestamp"
    done
}

# Main execution
main() {
    prepare_deployment
    # Get sender address
    if ! SENDER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY"); then
        echo -e "${RED}Error: Failed to derive sender address.${NC}"
        exit 1
    fi

    deploy_appgateway ScheduleAppGateway
    read_timeouts
    trigger_timeouts
    echo -e "${CYAN}Waiting for the highest timeout before reading logs...${NC}"
    progress_bar "$MAX_TIMEOUT"
    show_timeout_events

    #deposit_funds "$APP_GATEWAY"
    #progress_bar 5
    #withdraw_funds "$APP_GATEWAY" "$SENDER_ADDRESS"
}

# Run the main function
main
