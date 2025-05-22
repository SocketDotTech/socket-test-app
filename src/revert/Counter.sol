// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "socket-protocol/contracts/protocol/base/PlugBase.sol";

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
}
