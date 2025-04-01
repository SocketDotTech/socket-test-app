// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "socket-protocol/contracts/base/PlugBase.sol";

/**
 * @title Counter
 * @dev A simple contract that maintains a counter value which can be incremented
 * Used for multi-chain communication testing via SOCKET Protocol
 */
contract Counter is PlugBase {
    /**
     * @notice The current counter value
     * @dev Public variable that can be read directly or through the getter function
     */
    uint256 public counter;

    /**
     * @notice Increases the counter value by 1
     * @dev This function modifies the state by incrementing the counter variable
     */
    function increment() public {
        counter++;
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
