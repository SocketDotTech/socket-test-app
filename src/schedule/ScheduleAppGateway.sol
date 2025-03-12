// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";

contract ScheduleAppGateway is AppGatewayBase {
    uint256[] public resolveTimes = new uint256[](10);

    uint256[] public timeoutDurations = [1, 10, 20, 30, 40, 50, 100, 500, 1000, 10000];

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        _setOverrides(fees_);
    }

    function deployContracts(uint32) external async {
        return;
    }

    function initialize(uint32) public pure override {
        return;
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

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
