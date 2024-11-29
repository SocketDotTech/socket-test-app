// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Counter.sol";
import "socket-poc/contracts/base/AppDeployerBase.sol";

contract CounterDeployer is AppDeployerBase {
    address public counter;

    constructor(
        address addressResolver_,
        FeesData memory feesData_
    ) AppDeployerBase(addressResolver_, feesData_) Ownable(msg.sender) {
        counter = address(new Counter());
        creationCodeWithArgs[counter] = type(Counter).creationCode;
    }

    function deployContracts(
        uint32 chainSlug
    ) external async(abi.encode(chainSlug)) {
        _deploy(counter, chainSlug);
    }

    function initialize(uint32 chainSlug) public override async(abi.encode(chainSlug)) {
        address socket = getSocketAddress(chainSlug);
        address counterForwarder = forwarderAddresses[counter][chainSlug];
        Counter(counterForwarder).setSocket(socket);
    }
}
