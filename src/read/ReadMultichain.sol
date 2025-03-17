// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

/**
 * @title ReadMultichain
 * @dev A contract that stores an array of randomly generated values and can be deployed to multiple chains via SOCKET Protocol.
 * This contract inherits from PlugBase to enable SOCKET Protocol integration.
 * The values can be read from different chains in parallel through the ReadAppGateway.
 */
contract ReadMultichain is PlugBase {
    /**
     * @notice Array of randomly generated values
     * @dev An array of 10 uint256 values initialized with pseudo-random numbers between 1 and 10
     */
    uint256[] public values;

    /**
     * @notice Emitted when the values array is initialized
     * @param values The array of initialized values
     */
    event ValuesInitialized(uint256[] values);

    /**
     * @notice Constructs the ReadMultichain contract
     * @dev Initializes the values array with 10 pseudo-random numbers between 1 and 10
     * using block data and sender address as seed for randomness
     */
    constructor() {
        values = new uint256[](10);
        uint256 baseSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));

        for (uint256 i = 0; i < 10; i++) {
            uint256 uniqueSeed = uint256(keccak256(abi.encodePacked(baseSeed, i)));
            values[i] = (uniqueSeed % 10) + 1;
        }

        emit ValuesInitialized(values);
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
