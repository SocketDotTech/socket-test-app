// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IOnchainAppGateway {
    /**
     * @notice Triggers an operation to increase a value on the gateway
     * @param value The amount to increase
     * @return The transaction ID of the onchain message
     */
    function callFromChain(uint256 value) external returns (bytes32);

    /**
     * @notice Propagates the current value to another chain
     * @param targetChain The identifier of the destination chain
     * @return The transaction ID of the onchain message
     */
    function propagateToChain(uint256 value, uint32 targetChain) external returns (bytes32);
}
