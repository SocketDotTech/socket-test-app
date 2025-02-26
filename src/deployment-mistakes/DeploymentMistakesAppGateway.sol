// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./DeployOnchainMistakes.sol";

contract DeploymentMistakesAppGateway is AppGatewayBase {
    constructor(address addressResolver_, address deployerContract_, address auctionManager_, Fees memory fees_)
        AppGatewayBase(addressResolver_, auctionManager_)
    {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setOverrides(fees_);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
