// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

/**
 * @title WriteMultichain
 * @dev A simple counter contract that can be deployed to multiple chains via SOCKET Protocol.
 * This contract inherits from PlugBase to enable SOCKET Protocol integration.
 * The counter can only be incremented through the SOCKET Protocol via WriteAppGateway.
 */
contract WriteMultichain is PlugBase {
    /**
     * @notice The current counter value
     * @dev This value can only be incremented by authorized SOCKET Protocol calls
     */
    uint256 public counter;

    /**
     * @notice Emitted when the counter is increased
     * @param newValue The new value of the counter after the increase
     */
    event CounterIncreasedTo(uint256 newValue);

    /**
     * @notice Increases the counter by 1
     * @dev This function can only be called through the SOCKET Protocol
     * The onlySocket modifier ensures that only the SOCKET Forwarder contract can call this function
     * @return The new counter value after increasing
     */
    function increase() external onlySocket returns (uint256) {
        counter++;
        emit CounterIncreasedTo(counter);
        return counter;
    }

    /**
     * @notice Connects the contract to the SOCKET Protocol
     * @dev Sets up the contract for EVMx communication by calling the parent PlugBase method
     * @param appGateway_ Address of the application gateway contract
     * @param socket_ Address of the SOCKET Protocol contract
     * @param switchboard_ Address of the switchboard contract
     */
    function connectSocket(address appGateway_, address socket_, address switchboard_) external onlySocket {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
