#!/bin/bash

# ANSI color codes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
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
        local bar
        bar=$(printf "#%.0s" $(seq 1 $i))
        # Pad the bar with spaces to maintain fixed width
        printf "\rWaiting $duration sec: [%-${width}s] %d%%$" "$bar" "$percent"
        sleep "$interval"
    done
    printf "\n"
}

# Function to validate environment and build contracts
prepare_deployment() {
    echo -e "${CYAN}Building contracts${NC}"
    if ! forge build; then
        echo -e "${RED}Error:${NC} forge build failed. Check your contract code."
        exit 1
    fi

    # Check if .env exists and load it
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error:${NC} .env file not found!"
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
        echo -e "${RED}Error:${NC} EVMX_RPC, PRIVATE_KEY, or ADDRESS_RESOLVER is not set."
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
        echo -e "${RED}Error:${NC} Contract deployment failed."
        exit 1
    fi

    # Extract the deployed address
    local appgateway
    appgateway=$(echo "$output" | grep "Deployed to:" | awk '{print $3}')

    # Check if extraction was successful
    if [ -z "$appgateway" ]; then
        echo -e "${RED}Error:${NC} Failed to extract deployed address."
        exit 1
    fi

    echo -e "AppGateway: https://evmx.cloud.blockscout.com/address/$appgateway"
    export APP_GATEWAY="$appgateway"
}

# Helper function to parse and print the txhash
function parse_txhash() {
    local output=$1
    local path=$2
    local txhash
    txhash=$(echo "$output" | grep "^transactionHash" | awk '{print $2}')
    # Check if txhash is empty or invalid
    if [ -z "$txhash" ] || ! [[ "$txhash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error:${NC} Failed to extract valid transactionHash from output."
        echo "Extracted value: '$txhash'"
        exit 1
    fi

    echo "Tx Hash: https://$path.blockscout.com/tx/$txhash"
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
        echo -e "${RED}Error:${NC} Failed to deploy contract on chain id $chainid"
        exit 1
    fi
    parse_txhash "$output" "evmx.cloud"
}

# Function to verify onchain contracts
verify_onchain_contract() {
    local chain_id="$1"
    local address="$2"
    local path="$3"
    local name="$4"

    # Check if required parameters are provided
    if [ -z "$chain_id" ] || [ -z "$address" ] || [ -z "$path" ] || [ -z "$name" ]; then
        echo "Usage: verify_contract <chain_id> <address> <path> <name>"
        return 1
    fi

    echo -e "${CYAN}Verifying onchain contract $2 on chain id: $1${NC}"
    if [ "$chain_id" = "$ARB_SEP_CHAIN_ID" ]; then
        local output
        if ! output=$(forge verify-contract \
                --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
                --verifier-url "https://arbitrum-sepolia.blockscout.com/api" \
                --verifier blockscout \
                "$address" \
                "src/$path/$name.sol:$name"); then
            echo -e "${YELLOW}Warning:${NC} Failed to deploy contract on Arbitrum Sepolia."
        fi
    elif [ "$chain_id" = "$OP_SEP_CHAIN_ID" ]; then
        local output
        if ! output=$(forge verify-contract \
                --rpc-url "$OPTIMISM_SEPOLIA_RPC" \
                --verifier-url "https://optimism-sepolia.blockscout.com/api" \
                --verifier blockscout \
                "$address" \
                "src/$path/$name.sol:$name"); then
            echo -e "${YELLOW}Warning:${NC} Failed to deploy contract on Optimism Sepolia."
        fi
    else
        echo -e "${YELLOW}Unsupported chain ID:${NC} $chain_id"
    fi
}

# Function to fetch forwarder address from chain id
fetch_forwarder_and_onchain_address() {
    local contractname=$1
    local chainid=$2
    echo -e "${CYAN}Fetching forwarder address for contract '$contractname' on chain ID $chainid${NC}"

    # Retrieve contract ID
    local contractid
    if ! contractid=$(cast call "$APP_GATEWAY" "$contractname()(bytes32)" --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error:${NC} Failed to retrieve $contractname identifier."
        exit 1
    fi

    # Retrieve forwarder address
    local forwarder
    if ! forwarder=$(cast call "$APP_GATEWAY" \
        "forwarderAddresses(bytes32,uint32)(address)" \
        "$contractid" "$chainid" --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error:${NC} Failed to retrieve forwarder address for chain $chainid."
        exit 1
    fi

    # Check if the forwarder address is the zero address
    if [ "$forwarder" == "0x0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Error:${NC} Forwarder address is zero for chain $chainid."
        exit 1
    fi

    # Retrieve onchain address
    local onchain
    if ! onchain=$(cast call "$APP_GATEWAY" \
        "getOnChainAddress(bytes32,uint32)(address)" \
        "$contractid" "$chainid" --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error:${NC} Failed to retrieve onchain address for chain $chainid."
        exit 1
    fi

    # Check if the onchain address is the zero address
    if [ "$onchain" == "0x0000000000000000000000000000000000000000" ]; then
        echo -e "${RED}Error:${NC} onchain address is zero for chain $chainid."
        exit 1
    fi

    # Log the retrieved addresses
    echo "Forwarder for chain $chainid: $forwarder"
    echo "Onchain for chain $chainid: $onchain"

    # Handle dynamic chain ID exports (improving flexibility)
    case "$chainid" in
        "$ARB_SEP_CHAIN_ID")
            export ARB_FORWARDER="$forwarder"
            export ARB_ONCHAIN="$onchain"
            ;;
        "$OP_SEP_CHAIN_ID")
            export OP_FORWARDER="$forwarder"
            export OP_ONCHAIN="$onchain"
            ;;
        *)
            # Dynamically add more chain ID handling here if necessary
            echo -e "${YELLOW}Warning:${NC} Unknown chain ID $chainid. Forwarder not exported."
            ;;
    esac
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
        echo -e "${RED}Error:${NC} Failed to deposit fees."
        exit 1
    fi
    parse_txhash "$output" "arbitrum-sepolia"
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
        echo -e "${RED}Error:${NC} Failed to get available fees."
        exit 1
    fi

    local available_fees
    available_fees=$(echo "$output" | awk '{print $1}')

    # Ensure it's a valid integer before proceeding
    if ! [[ "$available_fees" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error:${NC} Invalid available fees value: $available_fees"
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
                echo -e "${RED}Error:${NC} Failed to withdraw fees."
                exit 1
            fi
            parse_txhash "$output" "evmx.cloud"
        else
            echo "No funds available for withdrawal after gas cost estimation."
            exit 0
        fi
    else
        echo "No available fees to withdraw."
        exit 0
    fi
}

# Function to fetch EVMx event logs
await_events() {
    local expected_new_events=$1  # Number of new events to expect
    local event=$2                # Event ABI
    local timeout=60              # Maximum wait time in seconds
    local interval=2              # Check every 2 seconds
    local elapsed=0               # Time elapsed

    echo -e "${CYAN}Waiting logs for $expected_new_events new events (waiting up to $timeout seconds)...${NC}"

    local logs_evmx
    local event_count_evmx

    while [ "$elapsed" -lt "$timeout" ]; do
        evmx_logs=$(cast logs --rpc-url "$EVMX_RPC" --address "$APP_GATEWAY" "$event")
        event_count_evmx=$(echo "$evmx_logs" | grep -c "blockHash")

        if [ -n "$event_count_evmx" ] && [ "$event_count_evmx" -ge "$expected_new_events" ]; then
            echo "Total CounterIncreased events on EVMx: $event_count_evmx (reached expected $expected_new_events)"
            break
        fi

        echo "Waiting for $expected_new_events logs on EVMx... Current count: $event_count_evmx (Elapsed: $elapsed/$timeout sec)"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    if [ "$event_count_evmx" -lt "$expected_new_events" ]; then
        echo -e "${RED}Error:${NC} Timed out after $timeout seconds. Expected $expected_new_events CounterIncreased logs on EVMx, but found $event_count_evmx."
        exit 1
    fi

}

####################################################
################### WRITE TESTS ####################
####################################################
# Function to validate correct events on EVMx and onchain
function verify_write_events() {
    echo -e "${CYAN}Verifying event sequence across chains...${NC}"

    # Fetch initial EVMx logs
    local evmx_logs=$(cast logs --rpc-url "$EVMX_RPC" --address "$APP_GATEWAY" "CounterIncreased(address,uint256,uint256)")

    local evmx_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            local value=$(cast to-dec "0x${BASH_REMATCH[1]:130:64}")
            evmx_values+=("$value")
        fi
    done <<< "$evmx_logs"

    # Fetch and parse Optimism logs
    local op_logs=$(cast logs --rpc-url "$OPTIMISM_SEPOLIA_RPC" --address "$OP_ONCHAIN" "CounterIncreasedTo(uint256)")
    local op_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            local value=$(cast to-dec "${BASH_REMATCH[1]}")
            op_values+=("$value")
        fi
    done <<< "$op_logs"

    # Verify first 10 values
    for ((i=0; i<10; i++)); do
        if [ "${evmx_values[i]}" != "${op_values[i]}" ]; then
            echo -e "${RED}Mismatch sequential write events:${NC}"
            echo "EVMx value: ${evmx_values[i]}"
            echo "Optimism value: ${op_values[i]}"
            exit 1
        fi
    done

    # Fetch and parse Arbitrum logs
    local arb_logs=$(cast logs --rpc-url "$ARBITRUM_SEPOLIA_RPC" --address "$ARB_ONCHAIN" "CounterIncreasedTo(uint256)")
    local arb_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            local value=$(cast to-dec "${BASH_REMATCH[1]}")
            arb_values+=("$value")
        fi
    done <<< "$arb_logs"

    # Verify next 10 events (Arbitrum)
    for ((i=10; i<20; i++)); do
        if [ "${evmx_values[i]}" != "${arb_values[i-10]}" ]; then
            echo -e "${YELLOW}Mismatch parallel write events:${NC} EVMx value: ${evmx_values[i]} Arbitrum value: ${arb_values[i-10]}"
        fi
    done

    # Verify last 5 values on both Arbitrum and Optimism
    local last_5_op=("${op_values[@]: -5}")
    local last_5_arb=("${arb_values[@]: -5}")
    local last_10_evmx=("${evmx_values[@]: -10}")

    for ((i=0; i<5; i++)); do
        if [ "${last_5_op[i]}" != "${last_5_arb[i]}" ]; then
            echo -e "${RED}Mismatch in alternate write events between Optimism and Arbitrum:${NC}"
            echo "Optimism value: ${last_5_op[i]}"
            echo "Arbitrum value: ${last_5_arb[i]}"
            exit 1
        fi
    done

    for ((i=0, j=0; i<10; i+=2, j++)); do
        if [[ "${last_10_evmx[i]}" != "${last_5_op[j]}" || "${last_10_evmx[i]}" != "${last_5_arb[j]}" ]]; then
            echo -e "${RED}Mismatch in alternate write events with EVMx:${NC}"
            echo "EVMx value: ${last_10_evmx[i]}"
            echo "Optimism/Arbitrum value: ${last_5_op[j]}/${last_5_arb[j]}"
            exit 1
        fi
    done
}

# Function to run all write tests
run_write_tests() {
    echo -e "${CYAN}Running all write tests functions...${NC}"
    # 1. Trigger Sequential Write
    echo -e "${CYAN}triggerSequentialWrite...${NC}"
    local output
    if ! output=$(cast send "$APP_GATEWAY" \
        "triggerSequentialWrite(address)" "$OP_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error:${NC} Failed to trigger sequential write"
        return 1
    fi
    parse_txhash "$output" "evmx.cloud"
    await_events 10 "CounterIncreased(address,uint256,uint256)"

    # 2. Trigger Parallel Write
    echo -e "${CYAN}triggerParallelWrite...${NC}"
    if ! output=$(cast send "$APP_GATEWAY" \
        "triggerParallelWrite(address)" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error:${NC} Failed to trigger parallel write"
        return 1
    fi
    parse_txhash "$output" "evmx.cloud"
    await_events 20 "CounterIncreased(address,uint256,uint256)"

    # 3. Trigger Alternating Write between chains
    echo -e "${CYAN}triggerAltWrite...${NC}"
    if ! output=$(cast send "$APP_GATEWAY" \
        "triggerAltWrite(address,address)" "$OP_FORWARDER" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error:${NC} Failed to trigger alternating write"
        return 1
    fi
    parse_txhash "$output" "evmx.cloud"
    await_events 30 "CounterIncreased(address,uint256,uint256)"
    verify_write_events
}

###################################################
################## READ TESTS #####################
###################################################
# Function to run all read tests
run_read_tests() {
    echo -e "${CYAN}Running all read tests functions...${NC}"
    # 1. Trigger Parallel Write
    echo -e "${CYAN}triggerParallelRead...${NC}"
    if ! output=$(cast send "$APP_GATEWAY" \
        "triggerParallelRead(address)" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error:${NC} Failed to trigger parallel read"
        return 1
    fi
    parse_txhash "$output" "evmx.cloud"
    await_events 10

    # 2. Trigger Alternating Write between chains
    echo -e "${CYAN}triggerAltRead...${NC}"
    if ! output=$(cast send "$APP_GATEWAY" \
        "triggerAltRead(address,address)" "$OP_FORWARDER" "$ARB_FORWARDER" \
        --rpc-url "$EVMX_RPC" \
        --private-key "$PRIVATE_KEY" \
        --legacy \
        --gas-price 0); then
        echo -e "${RED}Error:${NC} Failed to trigger alternating read"
        return 1
    fi
    parse_txhash "$output" "evmx.cloud"
    await_events 20 "ValueRead(address,uint256,uint256)"
}

###################################################
################ SCHEDULER TESTS ##################
###################################################
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
        echo -e "${RED}Error:${NC} Failed to trigger timeouts."
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
        echo -e "${YELLOW}Warning:${NC} Expected $NUMBER_OF_TIMEOUTS timeouts but found $event_count."
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
        echo -e "${RED}Error:${NC} Failed to derive sender address."
        exit 1
    fi

    if true; then
        ##### WRITE TESTS #####
        deploy_appgateway write WriteAppGateway
        deposit_funds
        progress_bar 3
        deploy_onchain $ARB_SEP_CHAIN_ID
        deploy_onchain $OP_SEP_CHAIN_ID
        progress_bar 10
        fetch_forwarder_and_onchain_address 'multichain' $ARB_SEP_CHAIN_ID
        verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$ARB_ONCHAIN" write WriteMultichain
        fetch_forwarder_and_onchain_address 'multichain' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" write WriteMultichain
        run_write_tests
        withdraw_funds

        ##### READ TESTS #####
        deploy_appgateway read ReadAppGateway
        deposit_funds
        progress_bar 3
        deploy_onchain $ARB_SEP_CHAIN_ID
        deploy_onchain $OP_SEP_CHAIN_ID
        progress_bar 10
        fetch_forwarder_and_onchain_address 'multichain' $ARB_SEP_CHAIN_ID
        verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$ARB_ONCHAIN" read ReadMultichain
        fetch_forwarder_and_onchain_address 'multichain' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" read ReadMultichain
        run_read_tests
        withdraw_funds

        ##### SCHEDULER TESTS #####
        deploy_appgateway schedule ScheduleAppGateway
        read_timeouts
        trigger_timeouts
        echo -e "${CYAN}Waiting for the highest timeout before reading logs...${NC}"
        progress_bar "$MAX_TIMEOUT"
        show_timeout_events
    fi
}

# Run the main function
main
