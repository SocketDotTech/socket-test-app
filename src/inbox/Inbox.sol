// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "socket-protocol/contracts/base/PlugBase.sol";

contract Inbox is Ownable, PlugBase {
    uint256 public value;

    // Message types
    uint32 public constant INCREASE_ON_GATEWAY = 1;
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    function increaseOnGateway(uint256 value_) external returns (bytes32) {
        return _callAppGateway(
            abi.encode(INCREASE_ON_GATEWAY, abi.encode(value)),
            bytes32(0)
        );
    }

    function propagateToAnother(uint32 targetChain) external returns (bytes32) {
        return _callAppGateway(
            abi.encode(PROPAGATE_TO_ANOTHER, abi.encode(value, targetChain)),
            bytes32(0)
        );
    }

    function updateFromGateway(uint256 value_) external onlySocket {
        value = value_;
    }
}
