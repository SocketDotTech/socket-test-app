// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

interface IRobustnessMultichain {
    function counter() external;

    function values() external;

    function increase() external;

    function setValues(uint256[] memory values_) external;

    function getValue(uint256 index_) external;

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external;
}
