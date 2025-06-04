// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title IReadMultichain
 * @dev Interface for the ReadMultichain contract, defining its public functions
 * Used by the ReadAppGateway to interact with ReadMultichain instances across chains
 */
interface IReadMultichain {
    /**
     * @notice Retrieves a value at the specified index
     * @dev This function is view-only and does not modify state
     * @param index The index of the value to retrieve
     */
    function values(uint256 index) external;
}
