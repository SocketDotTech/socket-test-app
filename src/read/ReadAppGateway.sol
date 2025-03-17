// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "socket-protocol/contracts/interfaces/IForwarder.sol";
import "socket-protocol/contracts/interfaces/IPromise.sol";
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
    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(ReadMultichain).creationCode);
        _setOverrides(fees_);
        values = new uint256[](10);
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
    function initialize(uint32) public pure override {
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
        for (uint256 i = 0; i < 10; i++) {
            IReadMultichain(instance_).values(i);
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
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
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                IReadMultichain(instance1_).values(i);
                IPromise(instance1_).then(this.handleValue.selector, abi.encode(i, instance1_));
            } else {
                IReadMultichain(instance2_).values(i);
                IPromise(instance2_).then(this.handleValue.selector, abi.encode(i, instance2_));
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
     * @notice Updates the fee configuration
     * @dev Allows modification of fee settings for multi-chain operations
     * @param fees_ New fee configuration
     */
    function setFees(Fees memory fees_) public {
        fees = fees_;
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
