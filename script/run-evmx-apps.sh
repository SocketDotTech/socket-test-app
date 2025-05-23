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
        printf "\r${YELLOW}Waiting $duration sec:${NC} [%-${width}s] %d%%$" "$bar" "$percent"
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

    # Ensure required variables are set
    if [ -z "$EVMX_RPC" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESS_RESOLVER" ] || [ -z "$FEES_MANAGER" ]; then
        echo -e "${RED}Error:${NC} EVMX_RPC, PRIVATE_KEY, or ADDRESS_RESOLVER is not set."
        exit 1
    fi

    # Check for jq and install if not present
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${CYAN}jq not found, attempting to install...${NC}"
        # Detect OS
        case "$(uname -s)" in
            Darwin)
                # macOS
                if ! command -v brew >/dev/null 2>&1; then
                    echo -e "${CYAN}Installing Homebrew first...${NC}"
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                fi
                brew install jq
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Error:${NC} Failed to install jq on macOS"
                    exit 1
                fi
                ;;
            Linux)
                # Ubuntu/Debian assumed
                sudo apt-get update
                sudo apt-get install -y jq
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Error:${NC} Failed to install jq on Linux"
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}Error:${NC} Unsupported OS for automatic jq installation"
                exit 1
                ;;
        esac
        echo -e "${CYAN}jq installed successfully${NC}"
    fi

    # Constants
    export ARB_SEP_CHAIN_ID=421614
    export OP_SEP_CHAIN_ID=11155420
    export ETH_ADDRESS=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    export DEPLOY_FEES_AMOUNT=10000000000000000000  # 10 ETH in wei
    export FEES_AMOUNT=30000000000000000000  # 30 ETH in wei
    export TEST_USDC_AMOUNT="100000000"  # 100 TEST USDC
    export GAS_BUFFER="100000000"  # 0.1 Gwei in wei
    export GAS_LIMIT="50000000000"  # Gas limit estimate
    export EVMX_VERIFIER_URL="https://evmx.cloud.blockscout.com/api"
    export EVMX_API_BASE_URL="https://api-evmx-devnet.socket.tech"
}

# Function to deploy contract
deploy_appgateway() {
    local filefolder=$1
    local filename=$2
    local deploy_fees=${3:-$DEPLOY_FEES_AMOUNT}  # Use $3 if provided, otherwise default to $DEPLOY_FEES_AMOUNT

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
        --constructor-args "$ADDRESS_RESOLVER" "$deploy_fees"); then
        echo -e "${RED}Error:${NC} Contract deployment failed."
        exit 1
    fi

    parse_txhash "$output" "evmx.cloud"
    # Extract the deployed address
    local appgateway
    appgateway=$(echo "$output" | grep "Deployed to:" | awk '{print $3}')
    # Check if extraction was successful
    if [ -z "$appgateway" ]; then
        echo -e "${RED}Error:${NC} Failed to extract deployed address."
        exit 1
    fi

    echo -e "${GREEN}AppGateway:${NC} https://evmx.cloud.blockscout.com/address/$appgateway"
    export APP_GATEWAY="$appgateway"
}

# Helper function to parse and print the txhash
function parse_txhash() {
    local output=$1
    local path=$2
    local txhash
    txhash=$(echo "$output" | grep "^transactionHash" | awk '{print $2}')
    if [ -z "$txhash" ]; then
        txhash=$(echo "$output" | grep -i "Transaction hash:" | awk '{print $3}')
    fi

    # Check if txhash is empty or invalid
    if [ -z "$txhash" ] || ! [[ "$txhash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
        echo -e "${RED}Error:${NC} Failed to extract valid transactionHash from output."
        echo "Extracted value: '$txhash'"
        exit 1
    fi

    echo -e "${GREEN}Tx Hash:${NC} https://$path.blockscout.com/tx/$txhash"
    export LAST_TX_HASH=$txhash
}

# Function to send transactions with consistent error handling and logging
send_transaction() {
    local to="$1"
    local method="$2"
    local rpc="$3"
    local explorer="$4"
    shift 4  # Remove the first 4 arguments

    echo -e "${CYAN}Sending transaction to $method on $to${NC}"
    local output

    if [[ "$rpc" == "$EVMX_RPC" ]]; then
        # Special handling for EVMx
        if ! output=$(cast send "$to" \
            "$method" \
            "$@" \
            --rpc-url "$rpc" \
            --private-key "$PRIVATE_KEY" \
            --legacy \
            --gas-price 0); then
            echo -e "${RED}Error:${NC} Transaction failed on $explorer."
            return 1
        fi
    else
        # Regular transaction for other chains
        if ! output=$(cast send "$to" \
            "$method" \
            "$@" \
            --rpc-url "$rpc" \
            --private-key "$PRIVATE_KEY"); then
            echo -e "${RED}Error:${NC} Transaction failed on $explorer."
            return 1
        fi
    fi

    parse_txhash "$output" "$explorer"
    return 0
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
            echo -e "${YELLOW}Warning:${NC} Failed to verify contract on Arbitrum Sepolia."
        fi
    elif [ "$chain_id" = "$OP_SEP_CHAIN_ID" ]; then
        local output
        if ! output=$(forge verify-contract \
                --rpc-url "$OPTIMISM_SEPOLIA_RPC" \
                --verifier-url "https://optimism-sepolia.blockscout.com/api" \
                --verifier blockscout \
                "$address" \
                "src/$path/$name.sol:$name"); then
            echo -e "${YELLOW}Warning:${NC} Failed to verify contract on Optimism Sepolia."
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

    # Retrieve forwarder address with timeout
    local forwarder
    local attempts=0
    local max_attempts=30  # 60 seconds / 2 second sleep = 30 attempts
    local width=50        # Width of the progress bar
    local bar

    while true; do
        if ! forwarder=$(cast call "$APP_GATEWAY" \
            "forwarderAddresses(bytes32,uint32)(address)" \
            "$contractid" "$chainid" --rpc-url "$EVMX_RPC"); then
            echo -e "${RED}Error:${NC} Failed to retrieve forwarder address for chain $chainid."
            exit 1
        fi

        # Check if the forwarder address is not the zero address
        if [ "$forwarder" != "0x0000000000000000000000000000000000000000" ]; then
            if [ $attempts -ne 0 ]; then
                printf "\n"  # New line after progress bar
            fi
            break
        fi

        # Check if we've exceeded maximum attempts
        if [ $attempts -ge $max_attempts ]; then
            printf "\n"  # New line before error message
            echo -e "${RED}Error:${NC} Forwarder address is still zero after 60 seconds for chain $chainid."
            exit 1
        fi

        # Calculate progress bar
        local progress=$(( (attempts * width) / max_attempts ))
        local percent=$(( (attempts * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))

        # Print progress bar on the same line
        printf "\r${YELLOW}Waiting for forwarder:${NC} [%-${width}s] %d%%" "$bar" "$percent"

        sleep 2
        attempts=$((attempts + 1))
    done

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
    echo -e "${GREEN}Chain $chainid${NC}"
    echo -e "Forwarder: $forwarder"
    echo -e "Onchain:   $onchain"

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

# Function to check if there are available fees
check_available_fees() {
    local max_attempts=12  # 60 seconds / 5-second interval
    local attempt=0
    local available_fees="0"
    local output
    local width=50
    local bar
    while [ $attempt -lt $max_attempts ]; do
        if ! output=$(cast call "$FEES_MANAGER" \
            "getAvailableCredits(address)(uint256)" \
            "$APP_GATEWAY" \
            --rpc-url "$EVMX_RPC" 2>/dev/null); then
            printf "\r%*s\r" $((width + 30)) ""  # Clear the progress bar
            echo -e "${RED}Error:${NC} Failed to retrieve available fees."
            exit 1
        else
            # Extract the fees value
            available_fees=$(echo "$output" | awk '{print $1}')
            # Validate the fees value is a number
            if ! [[ "$available_fees" =~ ^[0-9]+$ ]]; then
                printf "\r%*s\r" $((width + 30)) ""  # Clear the progress bar
                echo -e "${RED}Error:${NC} Invalid fee value received."
                exit 1
            fi
        fi
        # Check if we got non-zero fees
        if [ "$available_fees" != "0" ]; then
            printf "\r%*s\r" $((width + 30)) ""  # Clear the progress bar
            echo -e "Funds available: $available_fees wei"
            return 0
        fi
        # Calculate progress bar
        local progress=$(( (attempt * width) / max_attempts ))
        local percent=$(( (attempt * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))
        # Print progress bar on the same line
        printf "\r${YELLOW}Checking fees:${NC} [%-${width}s] %d%%" "$bar" "$percent"
        sleep 5
        attempt=$((attempt + 1))
    done
    # If we get here, we've exceeded maximum attempts
    printf "\r%*s\r" $((width + 30)) ""  # Clear the progress bar
    echo -e "${RED}Error:${NC} No funds available after 60 seconds."
    exit 1
}

# Function to deposit funds
deposit_funds() {
    echo -e "${CYAN}Depositing funds${NC}"

    # Mint test USDC
    if ! send_transaction "$ARBITRUM_TEST_USDC" "mint(address,uint256)" "$ARBITRUM_SEPOLIA_RPC" "arbitrum-sepolia" "$WALLET_ADDRESS" "$TEST_USDC_AMOUNT"; then
        echo -e "${RED}Error:${NC} Failed to mint test USDC."
        return 1
    fi

    # Approve USDC for FeesPlug
    if ! send_transaction "$ARBITRUM_TEST_USDC" "approve(address,uint256)" "$ARBITRUM_SEPOLIA_RPC" "arbitrum-sepolia" "$ARBITRUM_FEES_PLUG" "$TEST_USDC_AMOUNT"; then
        echo -e "${RED}Error:${NC} Failed to approve test USDC to FeesPlug."
        return 1
    fi

    # Deposit funds
    if ! send_transaction "$ARBITRUM_FEES_PLUG" "depositToFeeAndNative(address,address,uint256)" "$ARBITRUM_SEPOLIA_RPC" "arbitrum-sepolia" "$ARBITRUM_TEST_USDC" "$APP_GATEWAY" "$TEST_USDC_AMOUNT"; then
        echo -e "${RED}Error:${NC} Failed to deposit to fees and native."
        return 1
    fi

    check_available_fees
}

# Function to withdraw funds
withdraw_funds() {
    echo -e "${CYAN}Withdrawing funds${NC}"

    # Get available fees from EVMX chain
    local output
    if ! output=$(cast call "$FEES_MANAGER" \
        "getAvailableCredits(address)(uint256)" \
        "$APP_GATEWAY" \
        --rpc-url "$EVMX_RPC" 2>/dev/null); then
        echo -e "${RED}Error:${NC} Failed to retrieve available fees."
        exit 1
    fi

    local available_fees
    available_fees=$(echo "$output" | awk '{print $1}')
    # Validate the fees value is a number
    if ! [[ "$available_fees" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error:${NC} Invalid fee value received."
        exit 1
    fi

    echo "Available Fees: $available_fees wei"
    # Check if there are funds to withdraw
    if [ "$available_fees" != "0" ]; then
        # Fetch gas price on Arbitrum Sepolia
        local arb_gas_price
        arb_gas_price=$(cast base-fee --rpc-url "$ARBITRUM_SEPOLIA_RPC")
        # Add buffer to gas price
        local gas_price
        local estimated_gas_cost
        gas_price=$(echo "$arb_gas_price + $GAS_BUFFER" | bc)
        estimated_gas_cost=$(echo "$GAS_LIMIT * $gas_price" | bc)
        # Calculate withdrawal amount
        local amount_to_withdraw=0
        if (( $(echo "$available_fees > $estimated_gas_cost" | bc -l) )); then
            amount_to_withdraw=$(echo "$available_fees - $estimated_gas_cost" | bc)
        fi
        echo "Withdrawing $amount_to_withdraw wei"
        if (( $(echo "$amount_to_withdraw > 0" | bc -l) )); then
            # Withdraw funds using send_transaction
            if ! send_transaction "$APP_GATEWAY" "withdrawFeeTokens(uint32,address,uint256,address)" "$EVMX_RPC" "evmx.cloud" "$ARB_SEP_CHAIN_ID" "$ARBITRUM_TEST_USDC" "$amount_to_withdraw" "$SENDER_ADDRESS"; then
                echo -e "${RED}Error:${NC} Failed to withdraw fees."
                exit 1
            fi
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
    local timeout=180              # Maximum wait time in seconds
    local interval=2              # Check every 2 seconds
    local elapsed=0               # Time elapsed

    printf "\r${CYAN}Waiting logs for %d new events (up to %d seconds)...${NC}" "$expected_new_events" "$timeout"

    local event_count_evmx=0

    while [ "$elapsed" -le "$timeout" ]; do
        evmx_logs=$(cast logs --rpc-url "$EVMX_RPC" --address "$APP_GATEWAY" "$event")
        event_count_evmx=$(echo "$evmx_logs" | grep -c "blockHash")

        if [ "$event_count_evmx" -ge "$expected_new_events" ]; then
            printf "\rTotal CounterIncreased events on EVMx: %d (reached expected %d)${NC}\n" "$event_count_evmx" "$expected_new_events"
            break
        fi

        # Update on same line
        printf "\rWaiting for %d logs on EVMx: %d/%d (Elapsed: %d/%d sec)" \
               "$expected_new_events" "$event_count_evmx" "$expected_new_events" "$elapsed" "$timeout"
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    if [ "$event_count_evmx" -lt "$expected_new_events" ]; then
        printf "\n${RED}Error:${NC} Timed out after %d seconds. Expected %d logs, found %d.\n" \
               "$timeout" "$expected_new_events" "$event_count_evmx"
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
    evmx_logs=$(cast logs --rpc-url "$EVMX_RPC" --address "$APP_GATEWAY" "CounterIncreased(address,uint256,uint256)")

    local evmx_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            value=$(cast to-dec "0x${BASH_REMATCH[1]:130:64}")
            evmx_values+=("$value")
        fi
    done <<< "$evmx_logs"

    # Fetch and parse Optimism logs
    op_logs=$(cast logs --rpc-url "$OPTIMISM_SEPOLIA_RPC" --address "$OP_ONCHAIN" "CounterIncreasedTo(uint256)")
    local op_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            value=$(cast to-dec "${BASH_REMATCH[1]}")
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
    arb_logs=$(cast logs --rpc-url "$ARBITRUM_SEPOLIA_RPC" --address "$ARB_ONCHAIN" "CounterIncreasedTo(uint256)")
    local arb_values=()
    while IFS= read -r line; do
        if [[ "$line" =~ data:\ (0x[0-9a-fA-F]+) ]]; then
            value=$(cast to-dec "${BASH_REMATCH[1]}")
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
    if ! send_transaction "$APP_GATEWAY" "triggerSequentialWrite(address)" "$EVMX_RPC" "evmx.cloud" "$OP_FORWARDER"; then
        echo -e "${RED}Error:${NC} Failed to trigger sequential write"
        return 1
    fi
    await_events 10 "CounterIncreased(address,uint256,uint256)"

    # 2. Trigger Parallel Write
    if ! send_transaction "$APP_GATEWAY" "triggerParallelWrite(address)" "$EVMX_RPC" "evmx.cloud" "$ARB_FORWARDER"; then
        echo -e "${RED}Error:${NC} Failed to trigger parallel write"
        return 1
    fi
    await_events 20 "CounterIncreased(address,uint256,uint256)"

    # 3. Trigger Alternating Write between chains
    if ! send_transaction "$APP_GATEWAY" "triggerAltWrite(address,address)" "$EVMX_RPC" "evmx.cloud" "$OP_FORWARDER" "$ARB_FORWARDER"; then
        echo -e "${RED}Error:${NC} Failed to trigger alternating write"
        return 1
    fi
    await_events 30 "CounterIncreased(address,uint256,uint256)"
    verify_write_events
}

###################################################
################## READ TESTS #####################
###################################################
# Function to run all read tests
run_read_tests() {
    echo -e "${CYAN}Running all read tests functions...${NC}"
    # 1. Trigger Parallel Read
    if ! send_transaction "$APP_GATEWAY" "triggerParallelRead(address)" "$EVMX_RPC" "evmx.cloud" "$ARB_FORWARDER"; then
        echo -e "${RED}Error:${NC} Failed to trigger parallel read"
        return 1
    fi
    await_events 10 "ValueRead(address,uint256,uint256)"

    # 2. Trigger Alternating Read between chains
    if ! send_transaction "$APP_GATEWAY" "triggerAltRead(address,address)" "$EVMX_RPC" "evmx.cloud" "$OP_FORWARDER" "$ARB_FORWARDER"; then
        echo -e "${RED}Error:${NC} Failed to trigger alternating read"
        return 1
    fi
    await_events 20 "ValueRead(address,uint256,uint256)"
}

###################################################
######## TRIGGER APPGATEWAY ONCHAIN TESTS #########
###################################################
# Function to run all tests to trigger the AppGateway from onchain contracts
run_trigger_appgateway_onchain_tests() {
    echo -e "${CYAN}Running all trigger the AppGateway from onchain tests functions...${NC}"

    local value_increase=5
    echo -e "${CYAN}Increase on AppGateway from Arbitrum Sepolia${NC}"
    if ! send_transaction "$ARB_ONCHAIN" "increaseOnGateway(uint256)" "$ARBITRUM_SEPOLIA_RPC" "arbitrum-sepolia" "$value_increase"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        return 1
    fi

    progress_bar 10
    if ! value_evmx=$(cast call "$APP_GATEWAY" \
        "valueOnGateway()" \
        --rpc-url "$EVMX_RPC"); then
        echo -e "${RED}Error:${NC} Failed to read valueOnGateway()"
        return 1
    fi

    # Convert hex to decimal for comparison
    value_evmx_dec=$(printf "%d" "$value_evmx")
    if [[ $value_evmx_dec -lt $value_increase ]]; then
        echo -e "${RED}Error:${NC} Got $value_evmx_dec but expected at least $value_increase"
        exit 1
    fi

    echo -e "${CYAN}Update on Optimism Sepolia from AppGateway${NC}"
    if ! send_transaction "$APP_GATEWAY" "updateOnchain(uint32)" "$EVMX_RPC" "evmx.cloud" "$OP_SEP_CHAIN_ID"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        return 1
    fi

    progress_bar 10
    if ! value_op=$(cast call "$OP_ONCHAIN" \
        "value()" \
        --rpc-url "$OPTIMISM_SEPOLIA_RPC"); then
        echo -e "${RED}Error:${NC} Failed to read value()"
        return 1
    fi

    value_op_dec=$(printf "%d" "$value_op")
    if [[ $value_evmx_dec -ne $value_op_dec ]]; then
        echo -e "${RED}Error:${NC} Got $value_op_dec but expected $value_evmx_dec"
        exit 1
    fi

    echo -e "${CYAN}Propagate update to Optimism Sepolia to Arbitrum Sepolia from AppGateway${NC}"
    if ! send_transaction "$OP_ONCHAIN" "propagateToAnother(uint32)" "$OPTIMISM_SEPOLIA_RPC" "optimism-sepolia" "$ARB_SEP_CHAIN_ID"; then
        echo -e "${RED}Error:${NC} Failed to send tx on Optimism Sepolia"
        return 1
    fi

    progress_bar 10
    if ! value_arb=$(cast call "$ARB_ONCHAIN" \
        "value()" \
        --rpc-url "$ARBITRUM_SEPOLIA_RPC"); then
        echo -e "${RED}Error:${NC} Failed to read value()"
        return 1
    fi

    value_arb_dec=$(printf "%d" "$value_arb")
    if [[ $value_arb_dec -ne $value_op_dec ]]; then
        echo -e "${RED}Error:${NC} Got $value_arb_dec but expected $value_op_dec"
        exit 1
    fi
}

###################################################
############## UPLOAD TO EVMx TESTS ###############
###################################################
# Function to run upload to EVMx tests
run_upload_tests() {
    local filefolder=$1
    local filename=$2
    echo -e "${CYAN}Deploying $filename contract${NC}"
    local output
    if ! output=$(forge create src/"$filefolder"/"$filename".sol:"$filename" \
        --rpc-url "$ARBITRUM_SEPOLIA_RPC" \
        --private-key "$PRIVATE_KEY" \
        --broadcast); then
        echo -e "${RED}Error:${NC} Contract deployment failed."
        exit 1
    fi

    # Extract the deployed address
    local counter
    counter=$(echo "$output" | grep "Deployed to:" | awk '{print $3}')
    # Check if extraction was successful
    if [ -z "$counter" ]; then
        echo -e "${RED}Error:${NC} Failed to extract deployed address."
        exit 1
    else
        echo "Counter: https://arbitrum-sepolia.blockscout.com/address/$counter"
    fi

    verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$counter" "$filefolder" "$filename"
    echo -e "${CYAN}Increment counter on Arbitrum Sepolia${NC}"
    if ! send_transaction "$counter" "increment()" "$ARBITRUM_SEPOLIA_RPC" "arbitrum-sepolia"; then
        echo -e "${RED}Error:${NC} Failed to send tx on Arbitrum Sepolia"
        exit 1
    fi

    echo -e "${CYAN}Upload counter to EVMx${NC}"
    if ! send_transaction "$APP_GATEWAY" "uploadToEVMx(address,uint32)" "$EVMX_RPC" "evmx.cloud" "$counter" "$ARB_SEP_CHAIN_ID"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        exit 1
    fi

    echo -e "${CYAN}Test read from Counter forwarder address${NC}"
    if ! send_transaction "$APP_GATEWAY" "read()" "$EVMX_RPC" "evmx.cloud"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        exit 1
    fi

    await_events 1 "ReadOnchain(address,uint256)"
}

###################################################
############# INSUFFICIENT FEES TESTS #############
###################################################
# Function to fetch the requestCount from a transaction hash
parse_request_count_from_tx_hash() {
    receipt=$(cast receipt "$LAST_TX_HASH" --rpc-url "$EVMX_RPC" --json)

    # Extract matching log's data field
    # cast keccak "RequestSubmitted(address,uint40,(bytes32,address,address,address,address,bytes32,bytes32,uint256,uint256,uint256,uint256,bytes,address)[])"
    request_submitted_keccak="0xb856562fcff2119ba754f0486f47c06087ebc1842bff464faf1b2a1f8d273b1d"
    data_hex=$(echo "$receipt" | jq -r --arg topic0 "$request_submitted_keccak" '
      .logs[]
      | select(.topics[0] == $topic0)
      | .data
    ')

    data_hex=$(echo "$data_hex" | sed 's/^0x//' | tr 'A-F' 'a-f')
    uint40_hex=${data_hex:64:64}
    uint40=$(echo "ibase=16; $(echo "$uint40_hex" | tr 'a-f' 'A-F')" | bc)
    echo "Payload requestCount (decimal): $uint40"
    export REQUEST_COUNT=$uint40
}

# Function to run insufficient fees to EVMx tests
run_insufficient_fees_tests() {
    local contractname=$1
    local chainid=$2
    echo -e "${CYAN}Testing fees for '$contractname' on chain $chainid${NC}"
    local contractid
    contractid=$(cast call "$APP_GATEWAY" "$contractname()(bytes32)" --rpc-url "$EVMX_RPC" || {
        echo -e "${RED}Error:${NC} Failed to get contract ID"
        exit 1
    })

    # Wait for valid forwarder address with progress bar
    local attempts=0
    local max_attempts=15
    local width=50
    local forwarder
    local bar
    while [ $attempts -lt $max_attempts ]; do
        forwarder=$(cast call "$APP_GATEWAY" \
            "forwarderAddresses(bytes32,uint32)(address)" \
            "$contractid" "$chainid" --rpc-url "$EVMX_RPC" || echo "error")

        if [ "$forwarder" != "error" ] && [ "$forwarder" != "0x0000000000000000000000000000000000000000" ]; then
            [ $attempts -ne 0 ] && printf "\n"
            echo "$forwarder"
            return 0
        fi

        local progress=$(( (attempts * width) / max_attempts ))
        local percent=$(( (attempts * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))
        printf "\r${YELLOW}Waiting for forwarder:${NC} [%-${width}s] %d%%" "$bar" "$percent"
        sleep 1
        attempts=$((attempts + 1))
    done
    printf "\n"
    echo "No valid forwarder after $max_attempts seconds"
    parse_request_count_from_tx_hash

    # Set fees
    send_transaction "$APP_GATEWAY" "increaseFees(uint40,uint256)" "$EVMX_RPC" "evmx.cloud" \
        "$REQUEST_COUNT" "$DEPLOY_FEES_AMOUNT" || {
        echo -e "${RED}Error:${NC} Failed to set fees"
        return 1
    }

    # Verify forwarder after fees
    attempts=0
    bar=""
    while [ $attempts -lt $max_attempts ]; do
        forwarder=$(cast call "$APP_GATEWAY" \
            "forwarderAddresses(bytes32,uint32)(address)" \
            "$contractid" "$chainid" --rpc-url "$EVMX_RPC" || echo "error")

        if [ "$forwarder" != "error" ] && [ "$forwarder" != "0x0000000000000000000000000000000000000000" ]; then
            [ $attempts -ne 0 ] && printf "\n"
            echo -e "${GREEN}Chain $chainid${NC}"
            echo -e "Forwarder: $forwarder"
            return 0
        fi

        local progress=$(( (attempts * width) / max_attempts ))
        local percent=$(( (attempts * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))
        printf "\r${YELLOW}Waiting for forwarder:${NC} [%-${width}s] %d%%" "$bar" "$percent"
        sleep 5
        attempts=$((attempts + 1))
    done
    printf "\n"
    echo -e "${RED}Error:${NC} No valid forwarder after $((max_attempts * 5)) seconds"
    exit 1
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
    if ! send_transaction "$APP_GATEWAY" "triggerTimeouts()" "$EVMX_RPC" "evmx.cloud"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        return 1
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

###################################################
################## REVERT TESTS ###################
###################################################
# Function to run the revert tests
run_revert_tests() {
    echo -e "${CYAN}Testing onchain revert${NC}"
    if ! send_transaction "$APP_GATEWAY" "testOnChainRevert(uint32)" "$EVMX_RPC" "evmx.cloud" "$OP_SEP_CHAIN_ID"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        exit 1
    fi

    local max_attempts=12  # 60 seconds / 5-second interval
    local attempt=0
    local status=""
    local response=""
    local width=50
    local bar

    echo -e "${CYAN}Waiting for transaction finalization${NC}"
    while true; do
        response=$(curl -s "$EVMX_API_BASE_URL/getDetailsByTxHash?txHash=$LAST_TX_HASH")
        status=$(echo "$response" | jq -r '.response[0].writePayloads[0].finalizeDetails.finalizeStatus')
        if [ "$status" = "FINALIZED" ]; then
            if [ $attempt -ne 0 ]; then
                printf "\n"  # New line after progress bar only if not first attempt
            fi
            break
        fi

        if [ $attempt -ge $max_attempts ]; then
            printf "\n"  # New line before error message
            echo -e "${RED}Error:${NC} Transaction not finalized after 60 seconds. Current status: $status"
            exit 1
        fi

        local progress=$(( (attempt * width) / max_attempts ))
        local percent=$(( (attempt * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))
        printf "\r${YELLOW}Waiting for finalization:${NC} [%-${width}s] %d%%" "$bar" "$percent"
        sleep 5
        attempt=$((attempt + 1))
    done

    execute_status=$(echo "$response" | jq -r '.response[0].writePayloads[0].executeDetails.executeStatus')
    if [ "$execute_status" = "EXECUTION_FAILED" ]; then
        echo "Execution status is EXECUTION_FAILED as expected"
    else
        echo -e "${RED}Error:${NC} Execution status is not EXECUTION_FAILED, it is: $execute_status"
        exit 1
    fi

    echo -e "${CYAN}Testing callback revert${NC}"
    if ! send_transaction "$APP_GATEWAY" "testCallbackRevertWrongInputArgs(uint32)" "$EVMX_RPC" "evmx.cloud" "$OP_SEP_CHAIN_ID"; then
        echo -e "${RED}Error:${NC} Failed to send tx on EVMx"
        exit 1
    fi

    attempt=0
    status=""
    response=""
    bar=0

    echo -e "${CYAN}Waiting for promise failed resolve${NC}"
    while true; do
        response=$(curl -s "$EVMX_API_BASE_URL/getDetailsByTxHash?txHash=$LAST_TX_HASH")
        status=$(echo "$response" | jq -r '.response[0].readPayloads[0].callBackDetails.callbackStatus')
        if [ "$status" = "PROMISE_RESOLVE_FAILED" ]; then
            if [ $attempt -ne 0 ]; then
                printf "\n"  # New line after progress bar only if not first attempt
            fi
            break
        fi

        if [ $attempt -ge $max_attempts ]; then
            printf "\n"  # New line before error message
            echo -e "${RED}Error:${NC} Transaction not finalized after 60 seconds. Current status: $status"
            exit 1
        fi

        local progress=$(( (attempt * width) / max_attempts ))
        local percent=$(( (attempt * 100) / max_attempts ))
        bar=$(printf "#%.0s" $(seq 1 $progress))
        printf "\r${YELLOW}Waiting for finalization:${NC} [%-${width}s] %d%%" "$bar" "$percent"
        sleep 5
        attempt=$((attempt + 1))
    done
}

###################################################
################# MAIN FUNCTIONS ##################
###################################################
# Help function to display usage
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -w    Run write tests"
    echo "  -r    Run read tests"
    echo "  -t    Run trigger tests"
    echo "  -u    Run upload tests"
    echo "  -s    Run scheduler tests"
    echo "  -a    Run all tests"
    echo "  -?    Show this help message"
    echo "If no options are provided, this help message is displayed."
}

main() {
    prepare_deployment
    # Get sender address
    if ! SENDER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY"); then
        echo -e "${RED}Error:${NC} Failed to derive sender address."
        exit 1
    fi

    # Write Tests function
    run_write_tests_func() {
        deploy_appgateway write WriteAppGateway
        deposit_funds
        deploy_onchain $ARB_SEP_CHAIN_ID
        deploy_onchain $OP_SEP_CHAIN_ID
        fetch_forwarder_and_onchain_address 'multichain' $ARB_SEP_CHAIN_ID
        verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$ARB_ONCHAIN" write WriteMultichain
        fetch_forwarder_and_onchain_address 'multichain' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" write WriteMultichain
        run_write_tests
        withdraw_funds
    }

    # Read Tests function
    run_read_tests_func() {
        deploy_appgateway read ReadAppGateway
        deposit_funds
        deploy_onchain $ARB_SEP_CHAIN_ID
        deploy_onchain $OP_SEP_CHAIN_ID
        fetch_forwarder_and_onchain_address 'multichain' $ARB_SEP_CHAIN_ID
        verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$ARB_ONCHAIN" read ReadMultichain
        fetch_forwarder_and_onchain_address 'multichain' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" read ReadMultichain
        run_read_tests
        withdraw_funds
    }

    # Trigger AppGateway from Onchain Tests function
    run_trigger_tests_func() {
        deploy_appgateway trigger-appgateway-onchain OnchainTriggerAppGateway
        deposit_funds
        deploy_onchain $ARB_SEP_CHAIN_ID
        deploy_onchain $OP_SEP_CHAIN_ID
        fetch_forwarder_and_onchain_address 'onchainToEVMx' $ARB_SEP_CHAIN_ID
        verify_onchain_contract "$ARB_SEP_CHAIN_ID" "$ARB_ONCHAIN" trigger-appgateway-onchain OnchainTrigger
        fetch_forwarder_and_onchain_address 'onchainToEVMx' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" trigger-appgateway-onchain OnchainTrigger
        run_trigger_appgateway_onchain_tests
        withdraw_funds
    }

    # Upload to EVMx Tests function
    run_upload_tests_func() {
        deploy_appgateway forwarder-on-evmx UploadAppGateway
        deposit_funds
        run_upload_tests forwarder-on-evmx Counter
        withdraw_funds
    }

    # Insufficient Fees Tests function
    run_insufficient_fees_tests_func() {
        deploy_appgateway read ReadAppGateway 0 # Zero Max fees to force no transmitter biding
        deposit_funds
        deploy_onchain $OP_SEP_CHAIN_ID
        run_insufficient_fees_tests 'multichain' $OP_SEP_CHAIN_ID
        withdraw_funds
    }

    # Scheduler Tests function
    run_scheduler_tests_func() {
        deploy_appgateway schedule ScheduleAppGateway
        deposit_funds
        read_timeouts
        trigger_timeouts
        echo -e "${CYAN}Waiting for the highest timeout before reading logs...${NC}"
        progress_bar "$MAX_TIMEOUT"
        show_timeout_events
    }

    # Revert Tests function
    run_revert_tests_func() {
        deploy_appgateway revert RevertAppGateway
        deposit_funds
        deploy_onchain $OP_SEP_CHAIN_ID
        fetch_forwarder_and_onchain_address 'counter' $OP_SEP_CHAIN_ID
        verify_onchain_contract "$OP_SEP_CHAIN_ID" "$OP_ONCHAIN" revert Counter
        run_revert_tests
        withdraw_funds
    }

    # To add a new test suite:
    # 1. Create a new function like run_new_tests_func()
    # 2. Add a new RUN_NEWTESTS=false variable below
    # 3. Add a new flag (e.g., 'n') to getopts string and case statement
    # 4. Add $RUN_NEWTESTS && run_new_tests_func to execution section

    # Flags - Add new flags here for new test suites
    RUN_WRITE=false
    RUN_READ=false
    RUN_TRIGGER=false
    RUN_UPLOAD=false
    RUN_FEES=false
    RUN_SCHEDULER=false
    RUN_REVERT=false
    RUN_ALL=false

    # Parse command line options
    # To extend: Add new single-letter flags to "wrthua" string
    # and corresponding case in the switch statement
    while getopts "wrtuisva?" opt; do
        case $opt in
            w) RUN_WRITE=true;;
            r) RUN_READ=true;;
            t) RUN_TRIGGER=true;;
            u) RUN_UPLOAD=true;;
            i) RUN_FEES=true;;
            s) RUN_SCHEDULER=true;;
            v) RUN_REVERT=true;;
            a) RUN_ALL=true;;
            ?) show_help; exit 0;;
        esac
    done

    # If no options specified, show help and exit
    if [ "$OPTIND" -eq 1 ]; then
        show_help
        exit 0
    fi

    # If -a is specified, set all test flags to true
    if $RUN_ALL; then
        RUN_WRITE=true
        RUN_READ=true
        RUN_TRIGGER=true
        RUN_UPLOAD=true
        RUN_FEES=true
        RUN_SCHEDULER=true
        RUN_REVERT=true
    fi

    # Execute selected tests
    # To extend: Add new $RUN_ condition and function call here
    $RUN_WRITE && run_write_tests_func
    $RUN_READ && run_read_tests_func
    $RUN_TRIGGER && run_trigger_tests_func
    $RUN_UPLOAD && run_upload_tests_func
    $RUN_FEES && run_insufficient_fees_tests_func
    $RUN_SCHEDULER && run_scheduler_tests_func
    $RUN_REVERT && run_revert_tests_func
}

# Run the main function with all arguments
main "$@"
