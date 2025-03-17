// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IOnchainTrigger
 * @dev Interface for the OnchainTrigger contract, defining its public functions
 * Used by the OnchainTriggerAppGateway to interact with OnchainTrigger instances across chains
 */
interface IOnchainTrigger {
    /**
     * @notice Returns the current value stored in the contract
     * @dev This function is callable from other contracts
     * @return The current value
     */
    function value() external returns (uint256);

    /**
     * @notice Triggers an operation to increase a value on the gateway
     * @dev Sends a message to the gateway to increase its value
     * @param value_ The amount to increase
     * @return The transaction ID of the onchain message
     */
    function increaseOnGateway(uint256 value_) external returns (bytes32);

    /**
     * @notice Propagates the current value to another chain
     * @dev Sends a onchain message to update a contract on a different chain
     * @param targetChain The identifier of the destination chain
     * @return The transaction ID of the onchain message
     */
    function propagateToAnother(uint32 targetChain) external returns (bytes32);

    /**
     * @notice Updates the contract's value from the gateway
     * @dev Can only be called by authorized EVMx communication
     * @param value The new value to store
     */
    function updateFromGateway(uint256 value) external;
}
