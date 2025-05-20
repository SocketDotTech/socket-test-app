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
    constructor(address addressResolver_, uint256 fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(WriteMultichain).creationCode);
        _setOverrides(fees_);
    }

    /**
     * @notice Deploys WriteMultichain contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async(bytes("")) {
        _deploy(multichain, chainSlug_, IsPlug.YES);
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev No initialization needed for this application, so implementation is empty.
     *      The chainSlug parameter is required by the interface but not used.
     */
    function initialize(uint32) public pure override {
        return;
    }

    /**
     * @notice Triggers sequential write operations on a single instance
     * @dev Calls the increase function 10 times in sequence and processes the return values
     * @param instance_ Address of the WriteMultichain instance to write to
     */
    function triggerSequentialWrite(address instance_) public async(bytes("")) {
        for (uint256 i = 0; i < 10; i++) {
            IWriteMultichain(instance_).increase();
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
        }
    }

    /**
     * @notice Triggers parallel write operations on a single instance
     * @dev Calls the increase function 10 times in parallel and processes the return values
     * @param instance_ Address of the WriteMultichain instance to write to
     */
    function triggerParallelWrite(address instance_) public async(bytes("")) {
        _setOverrides(Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            IWriteMultichain(instance_).increase();
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
        }
        _setOverrides(Parallel.OFF);
    }

    /**
     * @notice Triggers alternating write operations between two instances
     * @dev Calls the increase function alternately on two different instances
     * @param instance1_ Address of the first WriteMultichain instance
     * @param instance2_ Address of the second WriteMultichain instance
     */
    function triggerAltWrite(address instance1_, address instance2_) public async(bytes("")) {
        for (uint256 i = 0; i < 5; i++) {
            IWriteMultichain(instance1_).increase();
            IPromise(instance1_).then(this.handleValue.selector, abi.encode(i, instance1_));
            IWriteMultichain(instance2_).increase();
            IPromise(instance2_).then(this.handleValue.selector, abi.encode(i, instance2_));
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
    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
