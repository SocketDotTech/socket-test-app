// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./Inbox.sol";
import "socket-protocol/contracts/base/AppDeployerBase.sol";

contract InboxDeployer is AppDeployerBase {
    bytes32 public inbox = _createContractId("inbox");

    constructor(address addressResolver_, address auctionManager_, bytes32 sbType_, Fees memory fees_)
        AppDeployerBase(addressResolver_, auctionManager_, sbType_)
    {
        creationCodeWithArgs[inbox] = abi.encodePacked(type(Inbox).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(inbox, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }
}
