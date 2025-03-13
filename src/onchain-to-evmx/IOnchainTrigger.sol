// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IOnchainTrigger {
    function value() external returns (uint256);
    function increaseOnGateway(uint256 value_) external returns (bytes32);
    function propagateToAnother(uint32 targetChain) external returns (bytes32);
    function updateFromGateway(uint256 value) external;
}
