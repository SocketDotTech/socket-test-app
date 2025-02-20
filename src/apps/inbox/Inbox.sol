// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import "solady/auth/Ownable.sol";
import "socket-protocol/contracts/base/PlugBase.sol";

contract Inbox is Ownable, PlugBase {
    uint256 public testValue=0;

    // Message types
    uint32 public constant INCREASE_ON_GATEWAY = 1;
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    function increaseOnGateway() external returns (bytes32) {
        return _callAppGateway(
            abi.encode(INCREASE_ON_GATEWAY, abi.encode(testValue+1)), 
            bytes32(0)
        );
    }

    function propagateToAnother(uint32 _chainSlug) external returns (bytes32) { 
        return _callAppGateway(
            abi.encode(PROPAGATE_TO_ANOTHER, abi.encode(testValue+1, _chainSlug)), 
            bytes32(0)
        );
    }

    function pumpValue(uint256 value) external onlySocket {
        testValue = value;
    }
}