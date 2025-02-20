// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./Inbox.sol";
contract InboxGateway is AppGatewayBase {
    uint256 public testValue=0;
    
    // Message types
    uint32 public constant INCREASE_ON_GATEWAY = 1;
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    constructor(
        address addressResolver_,
        address deployerContract_,
        address auctionManager_,
        Fees memory fees_
    ) AppGatewayBase(addressResolver_, auctionManager_) {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setOverrides(fees_);
    }

    function callFromInbox(
        uint32,
        address,
        bytes calldata payload_,
        bytes32
    ) external override onlyWatcherPrecompile {
        (uint32 msgType, bytes memory payload) = abi.decode(payload_, (uint32, bytes));
        if (msgType == INCREASE_ON_GATEWAY) {
            uint256 value = abi.decode(payload, (uint256));
            if(testValue + 1 != value) {
                revert("InboxGateway: call invalid value");
            }
            testValue++;
        } else if (msgType == PROPAGATE_TO_ANOTHER) {
            (uint256 value, ) = abi.decode(payload, (uint256, uint32));
            if(testValue + 1 != value) {
                revert("InboxGateway: call invalid value");
            }
            testValue++;
            
            // Get the Inbox contract on target chain
            // address inboxAddress = addressResolver__().getAppAddress(targetChainSlug, "Inbox");
            // Inbox(inboxAddress).pumpValue(testValue);
        } else {
            revert("InboxGateway: invalid message type");
        }
    }
}