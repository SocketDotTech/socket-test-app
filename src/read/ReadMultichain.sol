// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

contract ReadMultichain is PlugBase {
    uint256[] public values;

    event ValuesInitialized(uint256[] values);

    constructor() {
        values = new uint256[](10);
        uint256 baseSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));

        for (uint256 i = 0; i < 10; i++) {
            uint256 uniqueSeed = uint256(keccak256(abi.encodePacked(baseSeed, i)));
            values[i] = (uniqueSeed % 10) + 1;
        }

        emit ValuesInitialized(values);
    }

    function connectSocket(address appGateway_, address socket_, address switchboard_) external {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
