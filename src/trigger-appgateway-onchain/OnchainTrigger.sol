// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "socket-protocol/contracts/protocol/base/PlugBase.sol";

/**
 * @title OnchainTrigger
 * @dev A contract that can send and receive values across chains via SOCKET Protocol.
 * This contract inherits from Ownable for access control and PlugBase to enable SOCKET Protocol integration.
 * It demonstrates various multi-chain communication patterns.
 */
contract OnchainTrigger is Ownable, PlugBase {
    /**
     * @notice The current value stored in the contract
     * @dev Can be updated through multi-chain communication
     */
    uint256 public value;

    /**
     * @notice Message type identifier for increasing value on the gateway
     * @dev Used to differentiate message types in multi-chain communication
     */
    uint32 public constant INCREASE_ON_GATEWAY = 1;

    /**
     * @notice Message type identifier for propagating value to another chain
     * @dev Used to differentiate message types in multi-chain communication
     */
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    /**
     * @notice Triggers an operation to increase a value on the gateway
     * @dev Sends a message to the gateway to increase its value using SOCKET Protocol
     * @param value_ The amount to increase
     * @return The transaction ID of the onchain message
     */
    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        //return _callAppGateway(abi.encode(INCREASE_ON_GATEWAY, abi.encode(value_)), bytes32(0));
    }

    /**
     * @notice Propagates the current value to another chain
     * @dev Sends a onchain message to update a contract on a different chain
     * @param targetChain The identifier of the destination chain
     * @return The transaction ID of the onchain message
     */
    function propagateToAnother(uint32 targetChain) external returns (bytes32) {
        //return _callAppGateway(abi.encode(PROPAGATE_TO_ANOTHER, abi.encode(value, targetChain)), bytes32(0));
    }

    /**
     * @notice Updates the contract's value from the gateway
     * @dev Can only be called through the SOCKET Protocol
     * The onlySocket modifier ensures that only authorized EVMx communication can update the value
     * @param value_ The new value to store
     */
    function updateFromGateway(uint256 value_) external onlySocket {
        value = value_;
    }
}
