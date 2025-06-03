// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "./IWriteMultichain.sol";
import "./WriteMultichain.sol";

/**
 * @title WriteAppGateway
 * @dev Gateway contract for the WriteMultichain application that manages multi-chain write operations
 * through SOCKET Protocol. This contract enables sequential, parallel, and alternating write patterns
 * across different blockchain networks.
 * Inherits from AppGatewayBase for SOCKET Protocol integration.
 */
contract WriteAppGateway is AppGatewayBase {
    /**
     * @notice Number of requests to call onchain
     * @dev Used to maximize number of requests done
     */
    uint256 public numberOfRequests = 10;

    /**
     * @notice Identifier for the WriteMultichain contract
     * @dev Used to track WriteMultichain contract instances across chains
     */
    bytes32 public multichain = _createContractId("WriteMultichain");

    /**
     * @notice Emitted when a counter is successfully increased
     * @param instance The address of the WriteMultichain instance
     * @param index The operation index in the sequence
     * @param value The new counter value after increasing
     */
    event CounterIncreased(address instance, uint256 index, uint256 value);

    /**
     * @notice Constructs the WriteAppGateway
     * @dev Sets up the creation code for the WriteMultichain contract and configures fee overrides
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(WriteMultichain).creationCode);
        _initializeAppGateway(addressResolver_);
        _setMaxFees(fees_);
    }

    /**
     * @notice Deploys WriteMultichain contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async {
        _deploy(multichain, chainSlug_, IsPlug.YES);
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev No initialization needed for this application, so implementation is empty.
     *      The chainSlug parameter is required by the interface but not used.
     */
    function initializeOnChain(uint32) public pure override {
        return;
    }

    /**
     * @notice Triggers sequential write operations on a single instance
     * @dev Calls the increase function 10 times in sequence and processes the return values
     * @param instance_ Address of the WriteMultichain instance to write to
     */
    function triggerSequentialWrite(address instance_) public async {
        for (uint256 i = 0; i < numberOfRequests; i++) {
            IWriteMultichain(instance_).increase();
            then(this.handleValue.selector, abi.encode(i, instance_));
        }
    }

    /**
     * @notice Triggers parallel write operations on a single instance
     * @dev Calls the increase function 10 times in parallel and processes the return values
     * @param instance_ Address of the WriteMultichain instance to write to
     */
    function triggerParallelWrite(address instance_) public async {
        _setOverrides(Parallel.ON);
        for (uint256 i = 0; i < numberOfRequests; i++) {
            IWriteMultichain(instance_).increase();
            then(this.handleValue.selector, abi.encode(i, instance_));
        }
        _setOverrides(Parallel.OFF);
    }

    /**
     * @notice Triggers alternating write operations between two instances
     * @dev Calls the increase function alternately on two different instances
     * @param instance1_ Address of the first WriteMultichain instance
     * @param instance2_ Address of the second WriteMultichain instance
     */
    function triggerAltWrite(address instance1_, address instance2_) public async {
        for (uint256 i = 0; i < numberOfRequests; i++) {
            if (i % 2 == 0) {
                IWriteMultichain(instance1_).increase();
                then(this.handleValue.selector, abi.encode(i, instance1_));
            } else {
                IWriteMultichain(instance2_).increase();
                then(this.handleValue.selector, abi.encode(i, instance2_));
            }
        }
    }

    /**
     * @notice Callback function to handle values after counter increases
     * @dev Processes the return data from write operations and emits events
     * @param data Encoded data containing the index and instance address
     * @param returnData Encoded return value from the write operation
     */
    function handleValue(bytes memory data, bytes memory returnData) public onlyPromises {
        (uint256 index_, address instance) = abi.decode(data, (uint256, address));
        uint256 value_ = abi.decode(returnData, (uint256));
        emit CounterIncreased(instance, index_, value_);
    }

    /**
     * @notice Withdraws fee tokens from the SOCKET Protocol
     * @dev Allows withdrawal of accumulated fees to a specified receiver
     * @param chainSlug_ The chain from which to withdraw fees
     * @param token_ The token address to withdraw
     * @param amount_ The amount to withdraw
     * @param receiver_ The address that will receive the withdrawn fees
     */
    function withdrawCredits(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawCredits(chainSlug_, token_, amount_, receiver_);
    }

    /**
     * @notice Transfers fee credits from this contract to a specified address
     * @dev Moves a specified amount of fee credits from the current contract to the given recipient
     * @param to_ The address to transfer credits to
     * @param amount_ The amount of credits to transfer
     */
    function transferCredits(address to_, uint256 amount_) external {
        feesManager__().transferCredits(address(this), to_, amount_);
    }

    /**
     * @notice Updates the fee max value
     * @dev Allows modification of fee settings for multi-chain operations
     * @param fees_ New fee configuration
     */
    function setMaxFees(uint256 fees_) public {
        maxFees = fees_;
    }
}
