// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title IWriteMultichain
 * @dev Interface for the WriteMultichain contract, defining its public functions
 * Used by the WriteAppGateway to interact with WriteMultichain instances across chains
 */
interface IWriteMultichain {
    /**
     * @notice Returns the current counter value
     * @dev This function is view-only and does not modify state
     */
    function counter() external;

    /**
     * @notice Increases the counter value by 1
     * @dev Can only be called by authorized accounts via the SOCKET Protocol
     */
    function increase() external;

    /**
     * @notice Connects the contract to the SOCKET Protocol
     * @dev Sets up the contract for EVMx communication
     * @param appGateway_ Address of the application gateway contract
     * @param socket_ Address of the SOCKET Protocol contract
     * @param switchboard_ Address of the switchboard contract
     */
    function connectSocket(address appGateway_, address socket_, address switchboard_) external;
}
