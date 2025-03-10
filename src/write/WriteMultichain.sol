// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

contract WriteMultichain is PlugBase {
    uint256 public counter;

    event CounterIncreasedTo(uint256);

    function increase() external onlySocket {
        counter++;
        emit CounterIncreasedTo(counter);
    }

    function connectSocket(address appGateway_, address socket_, address switchboard_) external {
        _connectSocket(appGateway_, socket_, switchboard_);
    }
}
