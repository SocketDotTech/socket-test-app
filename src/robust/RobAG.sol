// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
// import "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import "./RobPlug.sol";

contract RobAG is AppGatewayBase {

    uint256[] public values;
    uint256[] public resolveTimes;

    uint256[] public timeouts = [1, 10, 20, 30, 40, 50, 100, 500, 1000, 10000];



    constructor(address addressResolver_, address deployerContract_, address auctionManager_, Fees memory fees_)
        AppGatewayBase(addressResolver_, auctionManager_)
    {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setOverrides(fees_);
    }

    function triggerSequentialWrite(address instance_) public async {
        _setOverrides(Read.OFF, Parallel.OFF);
        for (uint256 i = 0; i < 10; i++) {
            RobPlug(instance_).increase();
        }
    }

    function triggerParallelWrite(address instance_) public async {
        _setOverrides(Read.OFF, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            RobPlug(instance_).increase();
        }
    }

    function triggerAltWrite(address instance1_, address instance2_) public async {
        _setOverrides(Read.OFF, Parallel.OFF);
        for (uint256 i = 0; i < 5; i++) {
            RobPlug(instance1_).increase();
            RobPlug(instance2_).increase();
        }
    }

    function triggerRead(address instance_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            RobPlug(instance_).getValue(i);
            IPromise(instance_).then(this.setValue.selector, abi.encode(i));
        }
    }

    function triggerAltRead(address instance1_, address instance2_) public async {
        _setOverrides(Read.ON, Parallel.ON);
        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                RobPlug(instance1_).getValue(i);
                IPromise(instance1_).then(this.setValue.selector, abi.encode(i));
            } else {
                RobPlug(instance2_).getValue(i);
                IPromise(instance2_).then(this.setValue.selector, abi.encode(i));
            }
        }
    }

    function triggerReadAndWrite(address instance_) public async {
        _setOverrides(Read.ON, Parallel.OFF);
        RobPlug(instance_).getValue(0);
        IPromise(instance_).then(this.setValue.selector, abi.encode(0));
        RobPlug(instance_).getValue(1);
        IPromise(instance_).then(this.setValue.selector, abi.encode(1));

        _setOverrides(Read.OFF);
        RobPlug(instance_).increase();
        RobPlug(instance_).increase();

        _setOverrides(Read.ON);
        RobPlug(instance_).getValue(2);
        IPromise(instance_).then(this.setValue.selector, abi.encode(2));
        RobPlug(instance_).getValue(3);
        IPromise(instance_).then(this.setValue.selector, abi.encode(3));

        _setOverrides(Read.OFF);
        RobPlug(instance_).increase();
        RobPlug(instance_).increase();
    }

    function triggerTimeouts() public {
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                0
            ),
            1
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                1
            ),
            10
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                2
            ),
            20
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                3
            ),
            30
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                4
            ),
            40
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                5
            ),
            50
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                6
            ),
            100
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                7
            ),
            500
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                8
            ),
            1000
        );
        watcherPrecompile__().setTimeout(
            address(this),
            abi.encodeWithSelector(
                this.resolveTimeout.selector,
                9
            ),
            10000
        );
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
