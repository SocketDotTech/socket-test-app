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
        # Calculate percentage based on current progress
        local percent=$(( (i * 100) / width ))
        # Create the bar string with # characters
        local bar=$(printf "#%.0s" $(seq 1 $i))
        # Pad the bar with spaces to maintain fixed width
        printf "\r${CYAN}Waiting $duration sec: [%-${width}s] %d%%${NC}" "$bar" "$percent"
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
    export OP_SEP_CHAIN_ID=11155420
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

# Function to deploy contract
deploy_appgateway() {
    local filefolder=$1
    local filename=$2
    echo -e "${CYAN}Deploying $filename contract${NC}"
    local output
    if ! output=$(forge create src/"$filefolder"/"$filename".sol:"$filename" \
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
    local appgateway
    appgateway=$(echo "$output" | grep "Deployed to:" | awk '{print $3}')

    # Check if extraction was successful
    if [ -z "$appgateway" ]; then
        echo -e "${RED}Error: Failed to extract deployed address.${NC}"
        exit 1
    fi

    echo -e "AppGateway: https://evmx.cloud.blockscout.com/address/$appgateway"
    export APP_GATEWAY="$appgateway"
}

# Function to deploy onchain contracts from chain id
deploy_onchain() {
    local chainid=$1
    echo -e "${CYAN}Deploying onchain contracts${NC}"

    echo -e "${CYAN}Deploying for chain id: $chainid${NC}"
    local output
    if ! output=$(cast send "$APP_GATEWAY" \
        "deployContracts(uint32)" "$chainid" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error: Failed to deploy contract on Arbitrum Sepolia.${NC}"
        exit 1
    fi

    local txhash
    txhash=$(echo "$output" | grep "^transactionHash" | awk '{print $2}')
    # Check if txhash is empty or invalid
    if [ -z "$txhash" ] || ! [[ "$txhash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error: Failed to extract valid transactionHash from withdraw output.${NC}"
        echo "Extracted value: '$txhash'"
        exit 1
    fi

    echo "Deploy onchain Tx Hash: https://evmx.cloud.blockscout.com/tx/$txhash"
}

# Function to fetch forwarder address from chain id
fetch_forwarder_address() {
    local contractname=$1
    local chainid=$2
    echo -e "${CYAN}Fetching forwarder address${NC}"

    local contractid
    if ! contractid=$(cast call "$APP_GATEWAY" "$contractname()(bytes32)" \
        --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error: Failed to retrieve $contractname identifier.${NC}"
        return 1
    fi

    local output
    if ! output=$(cast call "$APP_GATEWAY" \
        "forwarderAddresses(bytes32,uint32)(address)" \
        "$contractid" "$chainid" \
        --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error: Failed to retrieve forwarder address for chain $chainid.${NC}"
        exit 1
    fi

    # Output results
    echo -e "${GREEN}Forwarder for chain $chainid: $output${NC}"

    # Export the appropriate forwarder based on chain ID
    if [ "$chainid" -eq "$ARB_SEP_CHAIN_ID" ]; then
        export ARB_FORWARDER="$output"
    elif [ "$chainid" -eq "$OP_SEP_CHAIN_ID" ]; then
        export OP_FORWARDER="$output"
    else
        echo -e "${RED}Warning: Unknown chain ID $chainid. Forwarder not exported.${NC}"
        exit 1
    fi
}

# Function to deposit funds
deposit_funds() {
    echo -e "${CYAN}Depositing funds${NC}"

    # Deposit funds
    local output
    if ! output=$(cast send "$ARBITRUM_FEES_PLUG" \
        --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
        --private-key "$PRIVATE_KEY" \
        --value "$FEES_AMOUNT" \
        "deposit(address,address,uint256)" "$ETH_ADDRESS" "$APP_GATEWAY" "$FEES_AMOUNT"); then
        echo -e "${RED}Error: Failed to deposit fees.${NC}"
        exit 1
    fi

    local txhash
    txhash=$(echo "$output" | grep "^transactionHash" | awk '{print $2}')
    # Check if txhash is empty or invalid
    if [ -z "$txhash" ] || ! [[ "$txhash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error: Failed to extract valid transactionHash from deposit output.${NC}"
        echo "Extracted value: '$txhash'"
        exit 1
    fi

    echo "Deposit Tx Hash: https://arbitrum-sepolia.blockscout.com/tx/$txhash"
}

# Function to withdraw funds
withdraw_funds() {
    echo -e "${CYAN}Withdrawing funds${NC}"

    # Get available fees from EVMX chain
    local output
    if ! output=$(cast call "$FEES_MANAGER" \
        "getAvailableFees(uint32,address,address)(uint256)" \
        "$ARB_SEP_CHAIN_ID" "$APP_GATEWAY" "$ETH_ADDRESS" \
        --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error: Failed to get available fees.${NC}"
        exit 1
    fi

    local available_fees
    available_fees=$(echo "$output" | awk '{print $1}')

    # Ensure it's a valid integer before proceeding
    if ! [[ "$available_fees" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid available fees value: $available_fees${NC}"
        exit 1
    fi

    echo "Available Fees: $available_fees wei"

    # Check if there are funds to withdraw
    if [ "$available_fees" -gt 0 ]; then
        # Fetch gas price on Arbitrum Sepolia
        local arb_gas_price
        arb_gas_price=$(cast base-fee --rpc-url "$ARBITRUM_SEPOLIA_RPC")

        # Add buffer to gas price
        local gas_price=$((arb_gas_price + GAS_BUFFER))
        local estimated_gas_cost=$((GAS_LIMIT * gas_price))

        # Calculate withdrawal amount
        local amount_to_withdraw=0
        if [ "$available_fees" -gt "$estimated_gas_cost" ]; then
            amount_to_withdraw=$((available_fees - estimated_gas_cost))
        fi

        if [ "$amount_to_withdraw" -gt 0 ]; then
            # Withdraw funds from the contract
            local output
            if ! output=$(cast send "$APP_GATEWAY" \
                --rpc-url "$EVMX_RPC" \
                --private-key "$PRIVATE_KEY" \
                --legacy \
                --gas-price 0 \
                "withdrawFeeTokens(uint32,address,uint256,address)" \
                "$ARB_SEP_CHAIN_ID" "$ETH_ADDRESS" "$amount_to_withdraw" "$SENDER_ADDRESS"); then
                echo -e "${RED}Error: Failed to withdraw fees.${NC}"
                exit 1
            fi

            local txhash
            txhash=$(echo "$output" | grep "^transactionHash" | awk '{print $2}')
            # Check if txhash is empty or invalid
            if [ -z "$txhash" ] || ! [[ "$txhash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
                echo -e "${RED}Error: Failed to extract valid transactionHash from withdraw output.${NC}"
                echo "Extracted value: '$txhash'"
                exit 1
            fi

            echo "Withdraw Tx Hash: https://evmx.cloud.blockscout.com/tx/$txhash"
        else
            echo "No funds available for withdrawal after gas cost estimation."
            exit 0
        fi
    else
        echo "No available fees to withdraw."
        exit 0
    fi
}

# Function to run all write tests
run_write_tests() {
    echo -e "${CYAN}Running all write tests functions...${NC}"

    # 1. Trigger Sequential Write
    echo -e "${CYAN}triggerSequentialWrite...${NC}"
    local seq_output
    if ! seq_output=$(cast send "$APP_GATEWAY" \
        "triggerSequentialWrite(address)" "$OP_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error: Failed to trigger sequential write${NC}"
        return 1
    fi
    local seq_tx_hash
    seq_tx_hash=$(echo "$seq_output" | grep "^transactionHash" | awk '{print $2}')
    if [ -z "$seq_tx_hash" ] || ! [[ "$seq_tx_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error: Failed to extract valid transactionHash from sequential write${NC}"
        echo "Extracted value: '$seq_tx_hash'"
        return 1
    fi
    echo "Sequential Write Tx Hash: https://evmx.cloud.blockscout.com/tx/$seq_tx_hash"

    # 2. Trigger Parallel Write
    echo -e "${CYAN}triggerParallelWrite...${NC}"
    local par_output
    if ! par_output=$(cast send "$APP_GATEWAY" \
        "triggerParallelWrite(address)" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error: Failed to trigger parallel write${NC}"
        return 1
    fi
    local par_tx_hash
    par_tx_hash=$(echo "$par_output" | grep "^transactionHash" | awk '{print $2}')
    if [ -z "$par_tx_hash" ] || ! [[ "$par_tx_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error: Failed to extract valid transactionHash from parallel write${NC}"
        echo "Extracted value: '$par_tx_hash'"
        return 1
    fi
    echo "Parallel Write Tx Hash: https://evmx.cloud.blockscout.com/tx/$par_tx_hash"

    # 3. Trigger Alternating Write between chains
    echo -e "${CYAN}triggerAltWrite...${NC}"
    local alt_output
    if ! alt_output=$(cast send "$APP_GATEWAY" \
        "triggerAltWrite(address,address)" "$OP_FORWARDER" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error: Failed to trigger alternating write${NC}"
        return 1
    fi
    local alt_tx_hash
    alt_tx_hash=$(echo "$alt_output" | grep "^transactionHash" | awk '{print $2}')
    if [ -z "$alt_tx_hash" ] || ! [[ "$alt_tx_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error: Failed to extract valid transactionHash from alternating write${NC}"
        echo "Extracted value: '$alt_tx_hash'"
        return 1
    fi
    echo "Alternating Write Tx Hash: https://evmx.cloud.blockscout.com/tx/$alt_tx_hash"

    echo -e "${CYAN}All triggers executed successfully${NC}"
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

    deploy_appgateway write WriteAppGateway
    deposit_funds
    progress_bar 5
    deploy_onchain $ARB_SEP_CHAIN_ID
    deploy_onchain $OP_SEP_CHAIN_ID
    progress_bar 10
    fetch_forwarder_address 'multichain' $ARB_SEP_CHAIN_ID
    fetch_forwarder_address 'multichain' $OP_SEP_CHAIN_ID
    run_write_tests
    withdraw_funds

    # TODO: Remove this exit
    exit 0
    deploy_appgateway schedule ScheduleAppGateway
    read_timeouts
    trigger_timeouts
    echo -e "${CYAN}Waiting for the highest timeout before reading logs...${NC}"
    progress_bar "$MAX_TIMEOUT"
    show_timeout_events
}

# Run the main function
main
