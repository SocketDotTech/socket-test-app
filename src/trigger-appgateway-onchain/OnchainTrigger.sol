// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "socket-protocol/contracts/protocol/base/PlugBase.sol";

import "./IOnchainAppGateway.sol";

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
     * @notice Triggers an operation to increase a value on the gateway
     * @dev Sends a message to the gateway to increase its value using SOCKET Protocol
     * @param value_ The amount to increase
     * @return The transaction ID of the onchain message
     */
    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        return IOnchainAppGateway(address(socket__)).callFromChain(value_);
    }

    /**
     * @notice Propagates the current value to another chain
     * @dev Sends a onchain message to update a contract on a different chain
     * @param targetChain The identifier of the destination chain
     * @return The transaction ID of the onchain message
     */
    function propagateToAnother(uint32 targetChain) external returns (bytes32) {
        return IOnchainAppGateway(address(socket__)).propagateToChain(value, targetChain);
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
