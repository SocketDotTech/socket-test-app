// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "socket-protocol/contracts/evmx/interfaces/IForwarder.sol";
import "socket-protocol/contracts/utils/common/Constants.sol";
import "./IReadMultichain.sol";
import "./ReadMultichain.sol";

/**
 * @title ReadAppGateway
 * @dev Gateway contract for the ReadMultichain application that manages multi-chain deployments
 * and parallel read operations through SOCKET Protocol.
 * Inherits from AppGatewayBase for SOCKET Protocol integration.
 */
contract ReadAppGateway is AppGatewayBase {
    /**
     * @notice Number of requests to call onchain
     * @dev Used to maximize number of requests done
     */
    uint256 numberOfRequests = REQUEST_PAYLOAD_COUNT_LIMIT - 1;

    /**
     * @notice Identifier for the ReadMultichain contract
     * @dev Used to track ReadMultichain contract instances across chains
     */
    bytes32 public multichain = _createContractId("ReadMultichain");

    /**
     * @notice Storage for values read from multiple chains
     * @dev Array of length 10 to store values read from ReadMultichain instances
     */
    uint256[] public values;

    /**
     * @notice Emitted when a value is successfully read from a contract instance
     * @param instance The address of the ReadMultichain instance
     * @param index The index of the value in the values array
     * @param value The value read from the instance
     */
    event ValueRead(address instance, uint256 index, uint256 value);

    /**
     * @notice Constructs the ReadAppGateway
     * @dev Sets up the creation code for the ReadMultichain contract, configures fee overrides,
     * and initializes the values array.
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(ReadMultichain).creationCode);
        values = new uint256[](numberOfRequests);
        _initializeAppGateway(addressResolver_);
        _setMaxFees(fees_);
    }

    /**
     * @notice Deploys ReadMultichain contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol.
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
     * @notice Triggers parallel read operations on a single instance
     * @dev Reads all 10 values from a single ReadMultichain instance in parallel
     * and stores the results in the values array.
     * @param instance_ Address of the ReadMultichain instance to read from
     */
    function triggerParallelRead(address instance_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < numberOfRequests; i++) {
            IReadMultichain(instance_).values(i);
            then(this.handleValue.selector, abi.encode(i, instance_));
        }
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    /**
     * @notice Triggers alternating read operations between two instances
     * @dev Reads even-indexed values from instance1 and odd-indexed values from instance2
     * in parallel and stores the results in the values array.
     * @param instance1_ Address of the first ReadMultichain instance
     * @param instance2_ Address of the second ReadMultichain instance
     */
    function triggerAltRead(address instance1_, address instance2_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < numberOfRequests; i++) {
            if (i % 2 == 0) {
                IReadMultichain(instance1_).values(i);
                then(this.handleValue.selector, abi.encode(i, instance1_));
            } else {
                IReadMultichain(instance2_).values(i);
                then(this.handleValue.selector, abi.encode(i, instance2_));
            }
        }
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    /**
     * @notice Callback function to handle values read from ReadMultichain instances
     * @dev Processes the return data from read operations and stores it in the values array
     * @param data Encoded data containing the index and instance address
     * @param returnData Encoded return value from the read operation
     */
    function handleValue(bytes memory data, bytes memory returnData) public onlyPromises {
        (uint256 index_, address instance) = abi.decode(data, (uint256, address));
        uint256 value_ = abi.decode(returnData, (uint256));

        values[index_] = value_;
        emit ValueRead(instance, index_, value_);
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
        _withdrawCredits(chainSlug_, token_, amount_, maxFees, receiver_);
    }

    /**
     * @notice Increases the fee payment for a specific payload request
     * @dev Allows modification of fee settings for a specific payload
     * @param requestCount_ Request count taken from api or from RequestSubmitted event
     * @param newMaxFees_ New max fee limit for this payload request
     */
    function increaseFees(uint40 requestCount_, uint256 newMaxFees_) public {
        _increaseFees(requestCount_, newMaxFees_);
    }
}
