// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

interface IWriteMultichain {
    function counter() external;

    function increase() external;

    function connectSocket(address appGateway_, address socket_, address switchboard_) external;
}
