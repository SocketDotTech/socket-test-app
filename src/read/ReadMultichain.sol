// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

contract ReadMultichain is PlugBase {
    uint256[] public values;

    event ValuesInitialized(uint256[] values);

    constructor() {
        values = new uint256[](10);
        uint256 seed = (block.number % 10) + 1;
        for (uint256 i = 0; i < 10; i++) {
            values[i] = seed + i;
        }
        emit ValuesInitialized(values);
    }

    function getValue(uint256 index_) external view returns (uint256) {
        return values[index_];
    }

    function connectSocket(address appGateway_, address socket_, address switchboard_) external {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
