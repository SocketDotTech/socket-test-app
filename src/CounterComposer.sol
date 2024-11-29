// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-poc/contracts/base/AppGatewayBase.sol";
import "./Counter.sol";

contract CounterComposer is AppGatewayBase {
    constructor(
        address _addressResolver,
        address deployerContract_,
        FeesData memory feesData_
    ) AppGatewayBase(_addressResolver, feesData_) Ownable(msg.sender) {
        addressResolver.setContractsToGateways(deployerContract_);
    }

    function incrementCounter(address _instance) public async(abi.encode(_instance)) {
        Counter(_instance).increase();
    }
}
