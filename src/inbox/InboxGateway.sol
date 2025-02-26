// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "socket-protocol/contracts/base/AppGatewayBase.sol";

interface IInboxDeployer {
    function inbox() external pure returns (bytes32 bytecode);

    function forwarderAddresses(
        bytes32 contractId_,
        uint32 chainSlug_
    ) external view returns (address forwarderAddress);
}

interface IInbox {
    function updateFromGateway(uint256 value) external;
}

contract InboxGateway is AppGatewayBase {
    uint256 public value;
    address deployerAddress;

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
        deployerAddress = deployerContract_;
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
            value += 1;
        } else if (msgType == PROPAGATE_TO_ANOTHER) {
            (uint256 value, uint32 targetChain) = abi.decode(payload, (uint256, uint32));
            address inboxForwarderAddress = IInboxDeployer(deployerAddress).forwarderAddresses(IInboxDeployer(deployerAddress).inbox(), targetChain);
            IInbox(inboxForwarderAddress).updateFromGateway(value);
        } else {
            revert("InboxGateway: invalid message type");
        }
    }
}
