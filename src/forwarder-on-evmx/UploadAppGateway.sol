// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "socket-protocol/contracts/interfaces/IPromise.sol";
import "../forwarder-on-evmx//ICounter.sol";

contract UploadAppGateway is AppGatewayBase {
    address public counterForwarder;

    event ReadOnchain(address forwarder, uint256 value);

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {}

    function initialize(uint32 chainSlug_) public override {}

    function uploadToEVMx(address onchainContract, uint32 chainSlug_) public {
        counterForwarder = addressResolver__.getOrDeployForwarderContract(address(this), onchainContract, chainSlug_);
    }

    function read() public async {
        _setOverrides(Read.ON);
        ICounter(counterForwarder).counter();
        IPromise(counterForwarder).then(this.handleRead.selector, abi.encode(counterForwarder));
        _setOverrides(Read.OFF);
    }

    function handleRead(bytes memory data, bytes memory returnData) public onlyPromises {
        address instance = abi.decode(data, (address));
        uint256 value_ = abi.decode(returnData, (uint256));

        emit ReadOnchain(instance, value_);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
