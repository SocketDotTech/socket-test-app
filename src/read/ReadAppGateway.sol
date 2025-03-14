// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "socket-protocol/contracts/interfaces/IForwarder.sol";
import "socket-protocol/contracts/interfaces/IPromise.sol";
import "./IReadMultichain.sol";
import "./ReadMultichain.sol";

contract ReadAppGateway is AppGatewayBase {
    bytes32 public multichain = _createContractId("ReadMultichain");
    uint256[] public values;

    error OutOfBounds();

    event ValueRead(address instance, uint256 index, uint256 value);

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(ReadMultichain).creationCode);
        _setOverrides(fees_);
        values = new uint256[](10);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(multichain, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function triggerParallelRead(address instance_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            IReadMultichain(instance_).values(i);
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
        }
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    function triggerAltRead(address instance1_, address instance2_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                IReadMultichain(instance1_).values(i);
                IPromise(instance1_).then(this.handleValue.selector, abi.encode(i, instance1_));
            } else {
                IReadMultichain(instance2_).values(i);
                IPromise(instance2_).then(this.handleValue.selector, abi.encode(i, instance2_));
            }
        }
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    function handleValue(bytes memory data, bytes memory returnData) public onlyPromises {
        (uint256 index_, address instance) = abi.decode(data, (uint256, address));
        uint256 value_ = abi.decode(returnData, (uint256));

        if (index_ >= 10) revert OutOfBounds();
        values[index_] = value_;
        emit ValueRead(instance, index_, value_);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
