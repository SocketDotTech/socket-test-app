// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./IWriteMultichain.sol";
import "./WriteMultichain.sol";

contract WriteAppGateway is AppGatewayBase {
    bytes32 public multichain = _createContractId("WriteMultichain");

    event CounterIncreased(address instance, uint256 index, uint256 value);

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(WriteMultichain).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(multichain, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function triggerSequentialWrite(address instance_) public async {
        for (uint256 i = 0; i < 10; i++) {
            IWriteMultichain(instance_).increase();
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
        }
    }

    function triggerParallelWrite(address instance_) public async {
        _setOverrides(Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            IWriteMultichain(instance_).increase();
            IPromise(instance_).then(this.handleValue.selector, abi.encode(i, instance_));
        }
        _setOverrides(Parallel.OFF);
    }

    function triggerAltWrite(address instance1_, address instance2_) public async {
        for (uint256 i = 0; i < 5; i++) {
            IWriteMultichain(instance1_).increase();
            IPromise(instance1_).then(this.handleValue.selector, abi.encode(i, instance1_));
            IWriteMultichain(instance2_).increase();
            IPromise(instance2_).then(this.handleValue.selector, abi.encode(i, instance2_));
        }
    }

    function handleValue(bytes memory data, bytes memory returnData) public onlyPromises {
        (uint256 index_, address instance) = abi.decode(data, (uint256, address));
        uint256 value_ = abi.decode(returnData, (uint256));
        emit CounterIncreased(instance, index_, value_);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
