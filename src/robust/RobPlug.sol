// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

contract RobPlug is PlugBase {
    uint256 public counter;

    uint256[] public values;

    function increase() external onlySocket {
        counter++;
    }

    function setValues(uint256[] memory values_) external {
        values = new uint256[](10);
        values[0] = values_[0];
        values[1] = values_[1];
        values[2] = values_[2];
        values[3] = values_[3];
        values[4] = values_[4];
        values[5] = values_[5];
        values[6] = values_[6];
        values[7] = values_[7];
        values[8] = values_[8];
        values[9] = values_[9];
    }

    function getValue(uint256 index_) external view returns (uint256) {
        return values[index_];
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
