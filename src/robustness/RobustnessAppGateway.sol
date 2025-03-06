// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./IRobustnessMultichain.sol";
import "./RobustnessMultichain.sol";

contract RobustnessAppGateway is AppGatewayBase {
    bytes32 public multichain = _createContractId("RobustnessMultichain");
    uint256[] public values;
    uint256[] public resolveTimes = new uint256[](10);

    uint256[] public timeoutDurations = [1, 10, 20, 30, 40, 50, 100, 500, 1000, 10000];

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[multichain] = abi.encodePacked(type(RobustnessMultichain).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(multichain, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function triggerSequentialWrite(address instance_) public async {
        _setOverrides(Read.OFF, Parallel.OFF);
        for (uint256 i = 0; i < 10; i++) {
            IRobustnessMultichain(instance_).increase();
        }
    }

    function triggerParallelWrite(address instance_) public async {
        _setOverrides(Read.OFF, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            IRobustnessMultichain(instance_).increase();
        }
    }

    function triggerAltWrite(address instance1_, address instance2_) public async {
        _setOverrides(Read.OFF, Parallel.OFF);
        for (uint256 i = 0; i < 5; i++) {
            IRobustnessMultichain(instance1_).increase();
            IRobustnessMultichain(instance2_).increase();
        }
    }

    function triggerParallelRead(address instance_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            IRobustnessMultichain(instance_).getValue(i);
            IPromise(instance_).then(this.setValue.selector, abi.encode(i));
        }
    }

    function triggerAltRead(address instance1_, address instance2_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                IRobustnessMultichain(instance1_).getValue(i);
                IPromise(instance1_).then(this.setValue.selector, abi.encode(i));
            } else {
                IRobustnessMultichain(instance2_).getValue(i);
                IPromise(instance2_).then(this.setValue.selector, abi.encode(i));
            }
        }
    }

    function triggerReadAndWrite(address instance_) public async {
        _setOverrides(Read.ON, Parallel.OFF);
        IRobustnessMultichain(instance_).getValue(0);
        IPromise(instance_).then(this.setValue.selector, abi.encode(0));
        IRobustnessMultichain(instance_).getValue(1);
        IPromise(instance_).then(this.setValue.selector, abi.encode(1));

        _setOverrides(Read.OFF);
        IRobustnessMultichain(instance_).increase();
        IRobustnessMultichain(instance_).increase();

        _setOverrides(Read.ON);
        IRobustnessMultichain(instance_).getValue(2);
        IPromise(instance_).then(this.setValue.selector, abi.encode(2));
        IRobustnessMultichain(instance_).getValue(3);
        IPromise(instance_).then(this.setValue.selector, abi.encode(3));

        _setOverrides(Read.OFF);
        IRobustnessMultichain(instance_).increase();
        IRobustnessMultichain(instance_).increase();
    }

    function triggerTimeouts() public {
        for (uint256 i = 0; i < timeoutDurations.length; i++) {
            watcherPrecompile__().setTimeout(
                address(this), abi.encodeWithSelector(this.resolveTimeout.selector, i), timeoutDurations[i]
            );
        }
    }

    function resolveTimeout(uint256 index_) public {
        resolveTimes[index_] = block.timestamp;
    }

    function setValue(bytes memory data, bytes memory returnData) public onlyPromises {
        uint256 index_ = abi.decode(data, (uint256));
        uint256 value_ = abi.decode(returnData, (uint256));
        values[index_] = value_;
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
