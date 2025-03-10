// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./Inbox.sol";
import "./IInbox.sol";

contract InboxAppGateway is AppGatewayBase {
    bytes32 public inbox = _createContractId("inbox");
    uint256 public valueOnGateway;
    address deployerAddress;

    // Message types
    uint32 public constant INCREASE_ON_GATEWAY = 1;
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[inbox] = abi.encodePacked(type(Inbox).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(inbox, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function updateOnchain(uint32 targetChain) public {
        address inboxForwarderAddress = this.forwarderAddresses(this.inbox(), targetChain);
        IInbox(inboxForwarderAddress).updateFromGateway(valueOnGateway);
    }

    function callFromChain(uint32, address, bytes calldata payload_, bytes32) external override onlyWatcherPrecompile {
        (uint32 msgType, bytes memory payload) = abi.decode(payload_, (uint32, bytes));
        if (msgType == INCREASE_ON_GATEWAY) {
            uint256 valueOnchain = abi.decode(payload, (uint256));
            valueOnGateway += valueOnchain;
        } else if (msgType == PROPAGATE_TO_ANOTHER) {
            (uint256 valueOnchain, uint32 targetChain) = abi.decode(payload, (uint256, uint32));
            address inboxForwarderAddress = this.forwarderAddresses(this.inbox(), targetChain);
            IInbox(inboxForwarderAddress).updateFromGateway(valueOnchain);
        } else {
            revert("InboxGateway: invalid message type");
        }
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
